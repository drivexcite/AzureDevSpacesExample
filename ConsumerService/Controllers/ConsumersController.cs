using System.Net.Http;
using System.Threading.Tasks;
using ConsumerService.Configuration;
using Microsoft.AspNetCore.Mvc;
using Newtonsoft.Json.Linq;

namespace ConsumerService.Controllers
{
    [ApiController]
    public class ConsumersController : ControllerBase
    {
        private readonly IHttpClientFactory _httpClientFactory;
        private readonly ConsumersControllerConfiguration _configuration;

        public ConsumersController(IHttpClientFactory httpClientFactory, ConsumersControllerConfiguration configuration)
        {
            _httpClientFactory = httpClientFactory;
            _configuration = configuration;
        }

        [HttpGet]
        [Route("consumers/{consumerId}")]
        public async Task<IActionResult> GetConsumer(string consumerId)
        {
            var settingsUrl = $"{_configuration.ConfigurationServiceUrl}/settings/{consumerId}";

            var httpClient = _httpClientFactory.CreateClient();
            var settingsResponse = await httpClient.GetAsync(settingsUrl);

            if (!settingsResponse.IsSuccessStatusCode)
            {
                return BadRequest($"Something's wrong with a dependency: {settingsUrl}");
            }

            var settingsResponseContent = await settingsResponse.Content.ReadAsStringAsync();
            var settingsJson = JToken.Parse(settingsResponseContent);

            var optOut = settingsJson["optOut"].Value<bool>();
            return Ok(new { consumerId, name = "foo", optOut });
        }
    }
}
