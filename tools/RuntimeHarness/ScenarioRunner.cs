using System;
using System.Globalization;
using System.IO;
using System.Linq;
using Kingmaker;
using Kingmaker.AreaLogic.Cutscenes;
using Kingmaker.DialogSystem.Blueprints;
using Kingmaker.EntitySystem.Entities;
using Kingmaker.EntitySystem.Persistence;
using Kingmaker.UnitLogic.Commands;
using Kingmaker.PubSubSystem;
using KingmakerCutsceneSkip.Core;
using Newtonsoft.Json.Linq;
using UnityEngine;
using UnityModManagerNet;

namespace KingmakerCutsceneSkip.RuntimeHarness
{
    /// <summary>Executes the request's steps one per frame-poll, after loading the requested save from the main menu.</summary>
    internal sealed class ScenarioRunner
    {
        private enum Stage { WaitMainMenu, LoadingSave, Settling, Steps, Finished }

        private enum StepStatus { Running, Done, Failed }

        private readonly HarnessRequest request;
        private readonly EvidenceRecorder recorder;
        private readonly JObject result;
        private readonly double startedAt;
        private Stage stage = Stage.WaitMainMenu;
        private double stageStartedAt;
        private int stepIndex;
        private bool stepBegun;
        private double stepStartedAt;
        private double conditionMetAt;
        private int keyEventsSent;
        private SkipOperationReport reportAtStepBegin;
        private string stepFailure;
        private int quitCountdown = -1;
        private CutsceneSkipController subscribedController;

        public ScenarioRunner(HarnessRequest request, EvidenceRecorder recorder, JObject result)
        {
            this.request = request;
            this.recorder = recorder;
            this.result = result;
            startedAt = Time.realtimeSinceStartup;
            stageStartedAt = startedAt;
            EventBus.Subscribe(recorder);
        }

        public bool IsFinished => stage == Stage.Finished;

        private static CutsceneSkipController Controller => KingmakerCutsceneSkip.Main.Runtime?.Controller;

        private double Now => Time.realtimeSinceStartup;

        public void Tick()
        {
            if (quitCountdown >= 0)
            {
                if (quitCountdown-- == 0) Application.Quit();
                return;
            }

            if (stage == Stage.Finished) return;
            SubscribeToSkipReports();
            recorder.Tick(Controller);

            if (Now - startedAt > request.TimeoutSeconds)
            {
                Finish(false, "run timeout after " + request.TimeoutSeconds + "s at " + CurrentStepName());
                return;
            }

            switch (stage)
            {
                case Stage.WaitMainMenu:
                    TickWaitMainMenu();
                    break;
                case Stage.LoadingSave:
                    if (!LoadingProcess.Instance.IsLoadingInProcess && Game.Instance.CurrentlyLoadedArea != null &&
                        Game.Instance.Player != null && Game.Instance.CurrentMode != Kingmaker.GameModes.GameModeType.None)
                    {
                        Enter(Stage.Settling);
                        recorder.Event("saveLoaded", Game.Instance.CurrentlyLoadedArea.name);
                    }

                    break;
                case Stage.Settling:
                    if (Now - stageStartedAt >= 1.0) Enter(Stage.Steps);
                    break;
                case Stage.Steps:
                    TickSteps();
                    break;
            }
        }

        private void TickWaitMainMenu()
        {
            MainMenu menu = UnityEngine.Object.FindObjectOfType<MainMenu>();
            if (menu == null || LoadingProcess.Instance.IsLoadingInProcess || Now - stageStartedAt < 3.0) return;

            UnityModManager.UI.Instance?.ToggleWindow(false);
            string path = Path.Combine(Game.Instance.SaveManager.SavePath, request.Save);
            SaveInfo save = Game.Instance.SaveManager.LoadZipSave(path);
            if (save == null)
            {
                Finish(false, "fixture save could not be read: " + path);
                return;
            }

            recorder.Event("loadSave", request.Save);
            menu.LoadGame(save);
            Enter(Stage.LoadingSave);
        }

        private void TickSteps()
        {
            if (stepIndex >= request.Steps.Count)
            {
                Finish(true, null);
                return;
            }

            HarnessStep step = request.Steps[stepIndex];
            if (!stepBegun)
            {
                stepBegun = true;
                stepStartedAt = Now;
                conditionMetAt = double.NaN;
                keyEventsSent = 0;
                stepFailure = null;
                reportAtStepBegin = Controller?.LastReport;
                recorder.Event("stepBegin", step.ToString());
            }

            StepStatus status;
            try
            {
                status = Poll(step);
            }
            catch (Exception exception)
            {
                stepFailure = exception.ToString();
                status = StepStatus.Failed;
            }

            if (status == StepStatus.Running && Now - stepStartedAt > step.TimeoutSeconds)
            {
                stepFailure = "step timeout after " + step.TimeoutSeconds + "s";
                status = StepStatus.Failed;
            }

            if (status == StepStatus.Running) return;
            if (status == StepStatus.Failed)
            {
                recorder.Event("stepFailed", step + ": " + stepFailure);
                if (!step.Optional)
                {
                    recorder.Screenshot("failure_" + stepIndex);
                    WriteSnapshot("failure");
                    Finish(false, step + ": " + stepFailure);
                    return;
                }
            }
            else
            {
                recorder.Event("stepDone", step.ToString());
            }

            stepIndex++;
            stepBegun = false;
        }

        private StepStatus Poll(HarnessStep step)
        {
            Game game = Game.Instance;
            switch (step.Op)
            {
                case "wait":
                    return Now - stepStartedAt >= step.Seconds ? StepStatus.Done : StepStatus.Running;

                case "waitCutscene":
                    return Settled(game.CurrentMode == Kingmaker.GameModes.GameModeType.Cutscene && HasControllingCutscene(step.Match), step.Seconds);

                case "waitMode":
                    return Settled(string.Equals(game.CurrentMode.ToString(), step.Mode, StringComparison.Ordinal), step.Seconds);

                case "waitNotMode":
                    return Settled(!string.Equals(game.CurrentMode.ToString(), step.Mode, StringComparison.Ordinal), step.Seconds);

                case "pressKey":
                    return PressKey(step);

                case "skipDirect":
                    return Fail(!Controller.TryStart(), "skip declined: " + Controller.LastDeclineReason);

                case "cancelDirect":
                    return Fail(!Controller.TryCancel(), "nothing to cancel");

                case "waitSkipActive":
                    return Controller.IsSkipping ? StepStatus.Done : StepStatus.Running;

                case "waitSkipPhase":
                    return string.Equals(Controller.Phase.ToString(), step.Mode, StringComparison.Ordinal) ? StepStatus.Done : StepStatus.Running;

                case "waitSkipIdle":
                    return Controller.Phase == SkipPhase.Idle && !ReferenceEquals(Controller.LastReport, reportAtStepBegin)
                        ? StepStatus.Done : StepStatus.Running;

                case "expectNoSkip":
                    return Fail(Controller.Phase != SkipPhase.Idle || !ReferenceEquals(Controller.LastReport, reportAtStepBegin), "a skip started unexpectedly");

                case "snapshot":
                    WriteSnapshot(step.Label);
                    recorder.Screenshot("snapshot_" + step.Label);
                    return StepStatus.Done;

                case "screenshot":
                    recorder.Screenshot("shot_" + step.Label);
                    return StepStatus.Done;

                case "captureFor":
                    recorder.ExtendCapture(step.Seconds);
                    return StepStatus.Done;

                case "moveTo":
                    return MoveMainCharacter(game, step);

                case "answer":
                    return SelectAnswer(game, step.Index);

                case "advanceUntil":
                    return AdvanceDialoguesUntil(game, step);

                case "toggleMod":
                    UnityModManager.FindMod(ProductMetadata.Id).Active = step.Enabled;
                    recorder.Event("modToggled", step.Enabled);
                    return StepStatus.Done;

                case "armFault":
                    FaultInjection.Arm();
                    recorder.Event("faultArmed");
                    return StepStatus.Done;

                case "loadSave":
                    if (!stepBegun || double.IsNaN(conditionMetAt))
                    {
                        conditionMetAt = Now;
                        SaveInfo save = game.SaveManager.LoadZipSave(Path.Combine(game.SaveManager.SavePath, step.Save));
                        recorder.Event("loadSaveInGame", step.Save);
                        game.LoadGame(save);
                        return StepStatus.Running;
                    }

                    return Now - conditionMetAt > 1.0 && !LoadingProcess.Instance.IsLoadingInProcess && game.CurrentlyLoadedArea != null
                        ? StepStatus.Done : StepStatus.Running;

                default:
                    stepFailure = "unknown op " + step.Op;
                    return StepStatus.Failed;
            }
        }

        private StepStatus Settled(bool condition, double settleSeconds)
        {
            if (!condition)
            {
                conditionMetAt = double.NaN;
                return StepStatus.Running;
            }

            if (double.IsNaN(conditionMetAt)) conditionMetAt = Now;
            return Now - conditionMetAt >= settleSeconds ? StepStatus.Done : StepStatus.Running;
        }

        private StepStatus Fail(bool failed, string message)
        {
            if (!failed) return StepStatus.Done;
            stepFailure = message;
            return StepStatus.Failed;
        }

        /// <summary>Sends count presses (down, hold, up) spaced by intervalMs, as real OS key events.</summary>
        private StepStatus PressKey(HarnessStep step)
        {
            if (keyEventsSent == 0 && !NativeKeyboard.EnsureForeground())
            {
                stepFailure = "game window is not in the foreground; refusing to send input";
                return StepStatus.Failed;
            }

            double elapsedMs = (Now - stepStartedAt) * 1000.0;
            while (keyEventsSent < step.Count * 2)
            {
                int press = keyEventsSent / 2;
                bool down = keyEventsSent % 2 == 0;
                double dueMs = press * (double)Math.Max(step.IntervalMs, step.HoldMs + 30) + (down ? 0 : step.HoldMs);
                if (elapsedMs < dueMs) return StepStatus.Running;
                if (!NativeKeyboard.Send(step.Key, down))
                {
                    if (!down) NativeKeyboard.EnsureForeground();
                    stepFailure = "lost foreground while sending " + step.Key;
                    return StepStatus.Failed;
                }

                recorder.Event(down ? "keyDown" : "keyUp", step.Key);
                keyEventsSent++;
            }

            return StepStatus.Done;
        }

        /// <summary>
        /// Walks the main character toward a position with a native move command (as a click would). Completes on
        /// arrival or as soon as the game leaves ordinary play (a trigger started a cutscene or dialogue on the way).
        /// </summary>
        private StepStatus MoveMainCharacter(Game game, HarnessStep step)
        {
            if (game.CurrentMode != Kingmaker.GameModes.GameModeType.Default) return StepStatus.Done;
            UnitEntityData unit = game.Player.MainCharacter.Value;
            string[] parts = step.Position.Split(',');
            Vector3 target = new Vector3(
                float.Parse(parts[0], CultureInfo.InvariantCulture),
                float.Parse(parts[1], CultureInfo.InvariantCulture),
                float.Parse(parts[2], CultureInfo.InvariantCulture));
            if (double.IsNaN(conditionMetAt))
            {
                conditionMetAt = Now;
                unit.Commands.Run(new UnitMoveTo(target, 0.5f));
                recorder.Event("moveTo", step.Position);
            }

            Vector3 delta = unit.Position - target;
            delta.y = 0;
            return delta.magnitude < 1.0f ? StepStatus.Done : StepStatus.Running;
        }

        /// <summary>
        /// Progresses dialogues deterministically until the requested top mode appears: each step picks the first
        /// selectable answer not chosen earlier in this run (else the last one), at a fixed real-time cadence.
        /// The same rule is used for normal and skipped runs so both reach the same story branch.
        /// </summary>
        private StepStatus AdvanceDialoguesUntil(Game game, HarnessStep step)
        {
            if (string.Equals(game.CurrentMode.ToString(), step.Mode, StringComparison.Ordinal)) return StepStatus.Done;
            if (game.CurrentMode != Kingmaker.GameModes.GameModeType.Dialog || game.DialogController.Dialog == null) return StepStatus.Running;
            double interval = step.Seconds > 0 ? step.Seconds : 1.0;
            if (!double.IsNaN(conditionMetAt) && Now - conditionMetAt < interval) return StepStatus.Running;
            conditionMetAt = Now;

            BlueprintAnswer[] answers = game.DialogController.Answers.Where(answer => answer.CanSelect()).ToArray();
            if (answers.Length == 0) return StepStatus.Running;
            BlueprintAnswer choice = answers.FirstOrDefault(answer => chosenAnswers.Add(answer.AssetGuid)) ?? answers[answers.Length - 1];
            recorder.Event("answer", game.DialogController.CurrentCue?.name + " -> " + choice.name);
            game.DialogController.SelectAnswer(choice);
            return StepStatus.Running;
        }

        private readonly System.Collections.Generic.HashSet<string> chosenAnswers = new System.Collections.Generic.HashSet<string>();

        private StepStatus SelectAnswer(Game game, int index)
        {
            BlueprintAnswer[] answers = game.DialogController.Answers.ToArray();
            if (game.DialogController.Dialog == null || index >= answers.Length)
            {
                stepFailure = "no dialogue answer " + index;
                return StepStatus.Failed;
            }

            recorder.Event("answer", answers[index].name);
            game.DialogController.SelectAnswer(answers[index]);
            return StepStatus.Done;
        }

        private static bool HasControllingCutscene(string match)
        {
            return Game.Instance.State.Cutscenes.ToList().Any(player =>
                player != null && !player.IsFinished && !player.Destroyed && player.Exclusive && !player.Paused &&
                (string.IsNullOrEmpty(match) || (player.Cutscene != null && player.Cutscene.name.IndexOf(match, StringComparison.OrdinalIgnoreCase) >= 0)));
        }

        private void WriteSnapshot(string label)
        {
            recorder.WriteJson("snapshot-" + label + ".json", StateSnapshot.Capture(label));
        }

        private void SubscribeToSkipReports()
        {
            CutsceneSkipController controller = Controller;
            if (controller == null || ReferenceEquals(controller, subscribedController)) return;
            controller.OperationEnded += report => recorder.Event("skipEnded", JObject.FromObject(report));
            subscribedController = controller;
        }

        private string CurrentStepName()
        {
            return stage == Stage.Steps && stepIndex < request.Steps.Count ? request.Steps[stepIndex].ToString() : stage.ToString();
        }

        private void Enter(Stage next)
        {
            stage = next;
            stageStartedAt = Now;
            recorder.Event("stage", next.ToString());
        }

        public void Finish(bool passed, string failure)
        {
            if (stage == Stage.Finished) return;
            stage = Stage.Finished;
            result["status"] = passed ? "passed" : "failed";
            result["failure"] = failure;
            result["stepsCompleted"] = stepIndex;
            result["framesCaptured"] = recorder.FramesCaptured;
            result["finishedRealtime"] = Now;
            result["lastSkipReport"] = Controller?.LastReport != null ? JObject.FromObject(Controller.LastReport) : null;
            recorder.Event("finished", passed ? "passed" : "failed: " + failure);
            recorder.Flush();
            recorder.WriteJson("runtime-result.json", result);
            EventBus.Unsubscribe(recorder);
            if (request.ExitAfterCompletion) quitCountdown = 30;
        }
    }
}
