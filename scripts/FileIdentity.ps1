# File identity (volume serial number and file index) read from an open handle with GetFileInformationByHandle, using
# the native BY_HANDLE_FILE_INFORMATION layout. WriteChecked opens the destination once, compares the identity of that
# handle with the protected identities and only then truncates and writes through the same handle.
if (-not ('KmcsFileIdentity' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;
public static class KmcsFileIdentity {
    [StructLayout(LayoutKind.Sequential)]
    struct ByHandleFileInformation {
        public uint FileAttributes;
        public uint CreationTimeLow, CreationTimeHigh, LastAccessTimeLow, LastAccessTimeHigh, LastWriteTimeLow, LastWriteTimeHigh;
        public uint VolumeSerialNumber, FileSizeHigh, FileSizeLow, NumberOfLinks, FileIndexHigh, FileIndexLow;
    }
    [DllImport("kernel32.dll", SetLastError = true)] static extern bool GetFileInformationByHandle(SafeFileHandle h, out ByHandleFileInformation i);
    static string IdOf(SafeFileHandle handle) {
        ByHandleFileInformation i;
        if (!GetFileInformationByHandle(handle, out i)) throw new IOException("GetFileInformationByHandle failed: " + Marshal.GetLastWin32Error());
        return i.VolumeSerialNumber.ToString("x8") + ":" + i.FileIndexHigh.ToString("x8") + i.FileIndexLow.ToString("x8");
    }
    public static string Of(string path) {
        using (var f = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete)) return IdOf(f.SafeFileHandle);
    }
    // Reads the whole file through one handle and returns its identity with the bytes, so the bytes hashed and inspected
    // are one snapshot of one file.
    public static string ReadSnapshot(string path, out byte[] content) {
        using (var f = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.Read)) {
            string id = IdOf(f.SafeFileHandle);
            var buffer = new MemoryStream();
            f.CopyTo(buffer);
            content = buffer.ToArray();
            return id;
        }
    }
    public static string WriteChecked(string path, string[] protectedIds, byte[] content) {
        using (var f = new FileStream(path, FileMode.OpenOrCreate, FileAccess.Write, FileShare.Read)) {
            string id = IdOf(f.SafeFileHandle);
            foreach (var p in protectedIds) if (p != null && string.Equals(p, id, StringComparison.Ordinal)) throw new InvalidOperationException("The report path must not be the validated input (file identity " + id + ").");
            f.SetLength(0);
            f.Write(content, 0, content.Length);
            return id;
        }
    }
}
'@
}
