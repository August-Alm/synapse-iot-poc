using Azure.Storage.Blobs;
using Microsoft.Azure.WebJobs;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading.Tasks;

namespace RawDataProcessor
{
    public class ProcessTelemetryFunction
    {
        private readonly IConfiguration _configuration;

        public ProcessTelemetryFunction(IConfiguration configuration)
        {
            _configuration = configuration;
        }

        [FunctionName(nameof(ProcessTelemetryFunction))]
        public async Task Run(
            //[TimerTrigger("0 */2 * * * *", RunOnStartup = false)] TimerInfo myTimer, ILogger log)
            [BlobTrigger("telemetry-rawdata/year={year}/month={month}/date={date}/{fileName}", Connection="ParquetStorage")]Stream blobStream,
            string fileName, ILogger log)
        {
            var settings = await Settings.GetSettingsAsync(_configuration["SettingsStorage"]);
            var telemetryReader = new RawTelemetryReader(_configuration["RawTelemetryConnectionString"]);
            log.LogInformation($"Retrieving raw telemetry items since {settings.LastProcessingDate}");
            var rawTelemetryItems = await telemetryReader.ReadRawTelemetryRecordsSinceAsync(settings.LastProcessingDate);
            log.LogInformation($"{rawTelemetryItems.LongCount()} telemetry items retrieved from storage");
            if (!rawTelemetryItems.Any())
            {
                log.LogInformation("No telemetry data to process");
                return;
            }
            var p = new TelemetryParquetWriter();
            var parquetContents = p.CreateParquetContents(rawTelemetryItems);
            var blobUploader = new BlobUploader(_configuration["ParquetStorage"]);
            var uploadTasks = new List<Task>();
            foreach (var parquetContent in parquetContents)
            {
                log.LogInformation($"Uploading {parquetContent.Identifier} to storage");
                uploadTasks.Add(blobUploader.UploadBlobAsync("parquet-contents", parquetContent.Identifier, parquetContent.Content));
            }
            await Task.WhenAll(uploadTasks);
            log.LogInformation("Finished uploading parquet files to storage");
            var dateOfLastProcessedItem = rawTelemetryItems.Max(t => t.EnqueuedTimeUtc);
            settings.LastProcessingDate = dateOfLastProcessedItem;
            await settings.SaveSettingsAsync(_configuration["SettingsStorage"]);
        }
    }

    public class BlobUploader
    {
        private readonly BlobServiceClient _blobServiceClient;

        public BlobUploader(string connectionString)
        {
            _blobServiceClient = new BlobServiceClient(connectionString);
        }

        public async Task UploadBlobAsync(string container, string blobName, Stream content)
        {
            var containerClient = _blobServiceClient.GetBlobContainerClient(container);
            await containerClient.CreateIfNotExistsAsync();
            var blobClient = containerClient.GetBlobClient(blobName);
            await blobClient.UploadAsync(content, overwrite: true);
        }
    }
}
