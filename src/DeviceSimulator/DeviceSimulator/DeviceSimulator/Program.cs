using System;
using System.Collections.Generic;
using System.Text;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.Azure.Devices.Client;
using Microsoft.Extensions.Configuration;
using Newtonsoft.Json;

namespace DeviceSimulator
{
    class Program
    {
        private static bool _stopApplication = false;

        private static IConfiguration _configuration = GetConfiguration();

        private static IEnumerable<IConfigurationSection> Devices(string[] deviceIds)
        {
            if (deviceIds == null || deviceIds.Length == 0)
            {
                deviceIds = _configuration.GetSection("Devices").GetChildren().Select(r => r.Key).ToArray();
            }
            return deviceIds.Select(d => _configuration.GetSection($"Devices:{d}"));
        }

        static async Task Main(string[] deviceIds)
        {
            Console.CancelKeyPress += Console_CancelKeyPress;
            Console.WriteLine("Connecting to IoT Hub ... Press CTRL+C to stop application.");
            var devices = Devices(deviceIds);
            while (!_stopApplication)
            {
                foreach (var device in devices)
                {
                    var connString = device["ConnectionString"];
                    if (!String.IsNullOrWhiteSpace(connString))
                    {
                        var client = DeviceClient.CreateFromConnectionString(connString);
                        await client.OpenAsync();
                        var readings = device.GetSection("Readings").GetChildren().Select(r => r.Value);
                        var telemetry = GenerateSampleTelemetry(device.Key, readings);
                        var message = CreateDeviceMessageForTelemetryMessage(telemetry);
                        await client.SendEventAsync(message);
                        Console.WriteLine("Sent message {0}", telemetry);
                        await client.CloseAsync();
                    }
                }
            }
            Console.WriteLine("Stopping...");
            Console.WriteLine("Stopped.");
        }

        private static IConfiguration GetConfiguration()
        {
            return
                new ConfigurationBuilder()
                    .AddJsonFile("appsettings.json", optional: false)
                    .AddJsonFile("appsettings.local.json", optional: true)
                    .Build();
        }

        private static Message CreateDeviceMessageForTelemetryMessage(TelemetryMessage telemetry)
        {
            var message = new Message(Encoding.UTF8.GetBytes(JsonConvert.SerializeObject(telemetry)));
            // Setting ContentType and ContentEncoding to these values is required to be able to
            // store messages as JSON in Azure storage via IoT Hub routing.
            message.ContentType = "application/json";
            message.ContentEncoding = "UTF-8";
            return message;
        }

        private static TelemetryMessage GenerateSampleTelemetry(string deviceId, IEnumerable<string> tags)
        {
            return new TelemetryMessage()
            {
                Timestamp = DateTimeOffset.UtcNow,
                DeviceId = deviceId,
                Readings = Ranges.RandomReadings(tags)
            };
        }

        private static void Console_CancelKeyPress(object sender, ConsoleCancelEventArgs e)
        {
            _stopApplication = true;
            e.Cancel = true;
        }
    }
}
