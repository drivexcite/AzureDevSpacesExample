using System.Net.Http;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Newtonsoft.Json;

namespace ConsumerService.Controllers
{
    [ApiController]
    public class ConsumersController : ControllerBase
    {
        private readonly HttpClient _httpClient;
        private readonly string _configurationServiceUrl;

        public ConsumersController(HttpClient httpClient, string configurationServiceUrl)
        {
            _httpClient = httpClient;
            _configurationServiceUrl = configurationServiceUrl;
        }

        [HttpGet]
        [Route("consumers/{consumerId}")]
        public async Task<IActionResult> GetConsumer(string consumerId)
        {
            var settingsUrl = $"{_configurationServiceUrl}/settings/{consumerId}";
            var settingsResponse = await _httpClient.GetAsync(settingsUrl);

            if (!settingsResponse.IsSuccessStatusCode)
            {

            }


            var settingsResponseContent = await settingsResponse.Content.ReadAsStringAsync();

            var settingsJson = JsonConvert.DeserializeObject(settingsResponse)
        }
    }
}
