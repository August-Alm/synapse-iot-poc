using System;

namespace RawDataProcessor
{
    internal class TelemetryMessage
    {
        public string DeviceId { get; set; }
        public DateTimeOffset Timestamp { get; set; }
        public Reading[] Readings { get; set; }
    }

    internal class Reading
    {
        public string Tag { get; set; }
        public object Value { get; set; }
    }
}