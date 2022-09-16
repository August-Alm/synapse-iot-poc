using System;
using System.Linq;
using System.Collections.Generic;
using System.Text;

namespace DeviceSimulator
{
    class TelemetryMessage
    {
        public string DeviceId { get; set; }
        public DateTimeOffset Timestamp { get; set; }
        public Reading[] Readings { get; set; }

        public override string ToString()
        {
            var rs = String.Join(';', Readings.Select(r => r.ToString()));
            return $"{{{DeviceId}; {Timestamp.ToString()}; [{rs}]}}";
        }
    }

    class Reading
    {
        public string Tag { get; set; }
        public object Value { get; set; }

        public override string ToString()
        {
            return $"{Tag}={(double)Value}";
        }
    }
}
