"""Summarizes a run's diag.jsonl (written by the runtime harness's SkipDiagnostics).

Usage: python -I tools/native/summarize_diag.py <evidence-dir> [--waits N]

Per skip phase: real seconds, game seconds and game/real ratio; accelerated frames that were substepped, native, or cut
short (planned vs executed substeps, with the recorded stop reasons); and the cutscene commands on which the most real
time was spent while Advancing, with the bark handle state seen for them. Observation only.
"""
import collections
import json
import os
import sys


def load(evidence):
    rows = []
    with open(os.path.join(evidence, 'diag.jsonl'), encoding='utf-8') as handle:
        for line in handle:
            line = line.strip()
            if line:
                rows.append(json.loads(line))
    return [row for row in rows if 'f' in row]


def segments(rows):
    """Consecutive runs of the same skip phase."""
    current = None
    for row in rows:
        key = row['phase']
        if current is None or current['phase'] != key or row['f'] - current['last']['f'] > 5:
            if current:
                yield current
            current = {'phase': key, 'first': row, 'last': row, 'rows': []}
        current['last'] = row
        current['rows'].append(row)
    if current:
        yield current


def main():
    evidence = sys.argv[1]
    top = int(sys.argv[sys.argv.index('--waits') + 1]) if '--waits' in sys.argv else 8
    rows = load(evidence)
    print('samples', len(rows))
    for seg in segments(rows):
        real = seg['last']['t'] - seg['first']['t']
        game = seg['last']['game'] - seg['first']['game']
        ratio = game / real if real > 0 else float('nan')
        print('\n== phase %-10s frames %5d real %7.2fs game %7.2fs ratio %5.2f dts %s..%s tc %s' % (
            seg['phase'], len(seg['rows']), real, game, ratio, seg['first']['dts'], seg['last']['dts'],
            sorted({row['tc'] for row in seg['rows']})))
        drv = [row['drv'] for row in seg['rows'] if 'drv' in row]
        if drv:
            native = sum(1 for d in drv if d['r'] == 'native')
            cut = [d for d in drv if d['r'] == 'substepped' and d['executed'] < d['planned']]
            planned = sum(d['planned'] for d in drv if d['r'] == 'substepped')
            executed = sum(d['executed'] for d in drv if d['r'] == 'substepped')
            print('   driver: frames %d, native %d, substepped %d, cut short %d, substeps planned %d executed %d' % (
                len(drv), native, len(drv) - native, len(cut), planned, executed))
            reasons = collections.Counter(d.get('stop', '?').split(': ', 1)[-1] for d in cut)
            for reason, count in reasons.most_common(6):
                print('      stop %4d x %s' % (count, reason))
        if seg['phase'] != 'Advancing':
            continue
        # Real time attributed to each playing command (a frame's real delta to every command playing in it).
        spent = collections.Counter()
        barks = {}
        previous = None
        for row in seg['rows']:
            if previous is not None:
                delta = row['t'] - previous['t']
                for cmd in previous.get('cmds', []):
                    spent[(cmd['cs'], cmd['c'], cmd['type'])] += delta
            for cmd in row.get('cmds', []):
                if cmd['type'] == 'CommandBark':
                    key = (cmd['cs'], cmd['c'], cmd['type'])
                    state = {k: cmd.get(k) for k in ('handle', 'playing', 'active', 'remaining', 'remainingReal', 'vo', 'speakerFog', 'finished', 'byText', 'await')}
                    barks.setdefault(key, []).append(state)
            previous = row
        print('   real time per playing command while Advancing:')
        for key, seconds in spent.most_common(top):
            line = '      %6.2fs  %s / %s (%s)' % (seconds, key[0], key[1], key[2])
            if key in barks:
                first, last = barks[key][0], barks[key][-1]
                line += '\n               first %s\n               last  %s' % (json.dumps(first), json.dumps(last))
            print(line)


if __name__ == '__main__':
    main()
