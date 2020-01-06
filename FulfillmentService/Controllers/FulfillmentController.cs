using System.Net.Http;
using System.Threading.Tasks;
using FulfillmentService.Configuration;
using Microsoft.AspNetCore.Mvc;
using Newtonsoft.Json.Linq;

namespace FulfillmentService.Controllers
{
    [ApiController]
    public class FulfillmentController : ControllerBase
    {
        private readonly IHttpClientFactory _httpClientFactory;
        private readonly FulfillmentControllerConfiguration _configuration;

        public FulfillmentController(IHttpClientFactory httpClientFactory, FulfillmentControllerConfiguration configuration)
        {
            _httpClientFactory = httpClientFactory;
            _configuration = configuration;
        }

        [HttpGet]
        [Route("fulfillment/{orderId}")]
        public async Task<IActionResult> GetConsumer(string orderId)
        {
            var consumerUrl = $"{_configuration.ConsumerServiceUrl}/consumer/{orderId}";

            var httpClient = _httpClientFactory.CreateClient();
            var consumerResponse = await httpClient.GetAsync(consumerUrl);

            if (!consumerResponse.IsSuccessStatusCode)
            {
                return BadRequest($"Something's wrong with a dependency: {consumerUrl}");
            }

            var consumerResponseContent = await consumerResponse.Content.ReadAsStringAsync();
            var consumerJson = JToken.Parse(consumerResponseContent);

            var consumerId = consumerJson["consumerId"].Value<string>();
            var name = consumerJson["name"].Value<string>();
            var optOut = consumerJson["optOut"].Value<bool>();

            return Ok(new { orderId, consumerId, name, optOut });
        }
    }
}
