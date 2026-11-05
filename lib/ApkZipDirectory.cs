using System;
using System.Buffers.Binary;
using System.IO;

namespace LocalDevTools
{
    public static class ApkZipDirectory
    {
        private const uint EndSignature = 0x06054b50;
        private const uint EntrySignature = 0x02014b50;
        private const int MaxEntries = 50000;
        private const int MaxDirectoryBytes = 32 * 1024 * 1024;

        public static void Validate(FileStream stream)
        {
            const int endSize = 22;
            long length = stream.Length;
            int tailSize = (int)Math.Min(length, endSize + ushort.MaxValue);
            stream.Position = length - tailSize;
            using (var reader = new BinaryReader(stream, System.Text.Encoding.UTF8, leaveOpen: true))
            {
                byte[] tail = reader.ReadBytes(tailSize);
                int end = tail.Length - endSize;
                // Choose the last signature with room for the fixed footer, as ZipArchive does.
                while (end >= 0 && BinaryPrimitives.ReadUInt32LittleEndian(tail.AsSpan(end)) != EndSignature)
                    end--;
                if (end < 0 || BinaryPrimitives.ReadUInt16LittleEndian(tail.AsSpan(end + 20)) != tail.Length - end - endSize)
                    throw new InvalidDataException("Missing or truncated ZIP end record.");

                long footer = length - tailSize + end;
                stream.Position = footer + 4;
                ushort disk = reader.ReadUInt16();
                ushort startDisk = reader.ReadUInt16();
                ushort diskEntries = reader.ReadUInt16();
                ushort entries = reader.ReadUInt16();
                uint size = reader.ReadUInt32();
                uint offset = reader.ReadUInt32();
                if (disk != 0 || startDisk != 0 || diskEntries != entries)
                    throw new InvalidDataException("Split or inconsistent ZIP directory.");

                ulong count = entries;
                ulong directorySize = size;
                ulong directoryOffset = offset;
                if (entries == ushort.MaxValue || offset == uint.MaxValue || size == uint.MaxValue)
                {
                    long locator = footer - 20;
                    if (locator < 0)
                        throw new InvalidDataException("Missing ZIP64 locator.");
                    stream.Position = locator;
                    if (reader.ReadUInt32() != 0x07064b50 || reader.ReadUInt32() != 0)
                        throw new InvalidDataException("Invalid ZIP64 locator.");
                    ulong record = reader.ReadUInt64();
                    if (reader.ReadUInt32() != 1 || locator < 56 || record > (ulong)(locator - 56))
                        throw new InvalidDataException("Invalid ZIP64 record offset.");

                    stream.Position = (long)record;
                    if (reader.ReadUInt32() != 0x06064b50)
                        throw new InvalidDataException("Missing ZIP64 end record.");
                    ulong recordSize = reader.ReadUInt64();
                    if (recordSize != (ulong)locator - record - 12)
                        throw new InvalidDataException("Invalid ZIP64 end record length.");
                    stream.Position += 4; // Version fields.
                    if (reader.ReadUInt32() != 0 || reader.ReadUInt32() != 0)
                        throw new InvalidDataException("Split ZIP64 directory.");
                    ulong zip64DiskEntries = reader.ReadUInt64();
                    count = reader.ReadUInt64();
                    directorySize = reader.ReadUInt64();
                    directoryOffset = reader.ReadUInt64();
                    if (zip64DiskEntries != count ||
                        (entries != ushort.MaxValue && count != entries) ||
                        (size != uint.MaxValue && directorySize != size) ||
                        (offset != uint.MaxValue && directoryOffset != offset) ||
                        // A size-only sentinel does not make every ZipArchive version use ZIP64.
                        (entries != ushort.MaxValue && offset != uint.MaxValue && size == uint.MaxValue))
                        throw new InvalidDataException("Conflicting ZIP and ZIP64 directory metadata.");
                    footer = (long)record;
                }

                if (count > MaxEntries)
                    throw new InvalidDataException("Archive exceeds 50,000-entry inspection limit.");
                if (directorySize > MaxDirectoryBytes)
                    throw new InvalidDataException("ZIP central directory exceeds the 32 MiB inspection limit.");
                if (directoryOffset > (ulong)footer || directorySize > (ulong)footer - directoryOffset)
                    throw new InvalidDataException("Invalid ZIP directory offset or size.");

                stream.Position = (long)directoryOffset;
                long directoryEnd = stream.Position + (long)directorySize;
                int actualCount = 0;
                while (stream.Position < directoryEnd)
                {
                    long header = stream.Position;
                    long remaining = directoryEnd - header;
                    if (remaining < 4)
                        throw new InvalidDataException("Truncated ZIP central directory record.");
                    uint signature = reader.ReadUInt32();
                    if (signature == 0x05054b50 && remaining >= 6 &&
                        reader.ReadUInt16() == remaining - 6)
                    {
                        stream.Position = directoryEnd;
                        break; // Optional central directory digital signature.
                    }
                    if (signature != EntrySignature || remaining < 46)
                        throw new InvalidDataException("Invalid ZIP central directory record.");
                    if (++actualCount > MaxEntries)
                        throw new InvalidDataException("Archive exceeds 50,000-entry inspection limit.");
                    stream.Position = header + 28;
                    int variableBytes = reader.ReadUInt16() + reader.ReadUInt16() + reader.ReadUInt16();
                    if (variableBytes > remaining - 46)
                        throw new InvalidDataException("Truncated ZIP central directory entry.");
                    stream.Position = header + 46 + variableBytes;
                }

                // ZipArchive reads until the first non-entry signature, ignoring the declared byte size.
                if (actualCount != (int)count ||
                    (length - directoryEnd >= 4 && reader.ReadUInt32() == EntrySignature))
                    throw new InvalidDataException("Conflicting ZIP central directory entry count or length.");
                stream.Position = 0;
            }
        }
    }
}
