using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace DeviceSimulator
{
    static class Ranges
    {
        private class Range
        {
            public double MinValue { get; }
            public double MaxValue { get; }

            public Range(double minValue, double maxValue)
            {
                MinValue = minValue;
                MaxValue = maxValue;
            }
        }

        private static readonly Dictionary<string, Range> RangeDictionary =
            new Dictionary<string, Range> () {
                { "temp", new Range(-5, 22) },
                { "humidity", new Range(35,80) },
                { "size", new Range(1, 170) },
                { "flux", new Range(0.5, 4.5) },
                { "current", new Range(0, 3.5) },
                { "voltage", new Range(0, 110) },
                { "ph", new Range(4, 12) },
                { "lumen", new Range(200, 3000) }
            };

        private static readonly Random Randomizer = new Random();

        private static Reading RandomReading(string tag)
        {
            if (RangeDictionary.TryGetValue(tag, out var range))
            {
                return new Reading
                {
                    Tag = tag,
                    Value = Randomizer.NextDouble() * (range.MaxValue - range.MinValue) + range.MinValue
                };
            }
            else
            {
                throw new ArgumentException($"{tag} is not a defined unit");
            }
        }

        public static Reading[] RandomReadings(IEnumerable<string> tags)
        {
            return tags.Select(tag => RandomReading(tag)).ToArray();
        }

    }
}
