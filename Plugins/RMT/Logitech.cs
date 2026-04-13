using System;
using System.Runtime.InteropServices;

namespace RMT
{
    public static class Logitech
    {
        #region Structs

        [StructLayout(LayoutKind.Sequential)]
        struct UNICODE_STRING
        {
            public ushort Length;
            public ushort MaximumLength;
            public IntPtr Buffer;
        }

        [StructLayout(LayoutKind.Sequential)]
        struct OBJECT_ATTRIBUTES
        {
            public int Length;
            public IntPtr RootDirectory;
            public IntPtr ObjectName;
            public uint Attributes;
            public IntPtr SecurityDescriptor;
            public IntPtr SecurityQualityOfService;
        }

        [StructLayout(LayoutKind.Sequential)]
        struct IO_STATUS_BLOCK
        {
            public IntPtr Status;
            public IntPtr Information;
        }

        #endregion

        #region Native API

        [DllImport("ntdll.dll")]
        static extern int NtCreateFile(
            out IntPtr FileHandle,
            uint DesiredAccess,
            ref OBJECT_ATTRIBUTES ObjectAttributes,
            out IO_STATUS_BLOCK IoStatusBlock,
            IntPtr AllocationSize,
            uint FileAttributes,
            uint ShareAccess,
            uint CreateDisposition,
            uint CreateOptions,
            IntPtr EaBuffer,
            uint EaLength
        );

        [DllImport("ntdll.dll")]
        static extern void RtlInitUnicodeString(
            ref UNICODE_STRING DestinationString,
            [MarshalAs(UnmanagedType.LPWStr)] string SourceString
        );

        #endregion

        #region Constants

        const uint GENERIC_WRITE = 0x40000000;
        const uint SYNCHRONIZE = 0x00100000;
        const uint FILE_ATTRIBUTE_NORMAL = 0x80;
        const uint OPEN_EXISTING = 3;
        const uint FILE_NON_DIRECTORY_FILE = 0x00000040;
        const uint FILE_SYNCHRONOUS_IO_NONALERT = 0x00000020;

        #endregion

        static IntPtr g_input = IntPtr.Zero;
        static IO_STATUS_BLOCK g_io;

        static bool NT_SUCCESS(int status)
        {
            return status >= 0;
        }

        static int device_initialize(string device_name)
        {
            var name = new UNICODE_STRING();
            RtlInitUnicodeString(ref name, device_name);

            IntPtr namePtr = Marshal.AllocHGlobal(Marshal.SizeOf(name));
            Marshal.StructureToPtr(name, namePtr, false);

            var attr = new OBJECT_ATTRIBUTES
            {
                Length = Marshal.SizeOf<OBJECT_ATTRIBUTES>(),
                ObjectName = namePtr,
                Attributes = 0,
                RootDirectory = IntPtr.Zero,
                SecurityDescriptor = IntPtr.Zero,
                SecurityQualityOfService = IntPtr.Zero
            };

            int status = NtCreateFile(
                out g_input,
                GENERIC_WRITE | SYNCHRONIZE,
                ref attr,
                out g_io,
                IntPtr.Zero,
                FILE_ATTRIBUTE_NORMAL,
                0,
                OPEN_EXISTING,
                FILE_NON_DIRECTORY_FILE | FILE_SYNCHRONOUS_IO_NONALERT,
                IntPtr.Zero,
                0
            );

            Marshal.FreeHGlobal(namePtr);
            return status;
        }

        public static bool MouseOpen()
        {
            int status = 0;

            if (g_input == IntPtr.Zero)
            {
                string buffer0 = @"\\??\\ROOT#SYSTEM#0002#{1abc05c0-c378-41b9-9cef-df1aba82b015}";

                status = device_initialize(buffer0);
                if (!NT_SUCCESS(status))
                {
                    string buffer1 = @"\\??\\ROOT#SYSTEM#0001#{1abc05c0-c378-41b9-9cef-df1aba82b015}";
                    status = device_initialize(buffer1);
                }
            }

            return status == 0;
        }
    }
}
