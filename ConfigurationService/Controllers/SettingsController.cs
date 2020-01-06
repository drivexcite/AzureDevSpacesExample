using System;
using Microsoft.AspNetCore.Mvc;

namespace ConfigurationService.Controllers
{
    [ApiController]
    public class SettingsController : ControllerBase
    {
        [HttpGet]
        [Route("settings/{consumerId}")]
        public IActionResult GetSettings(string consumerId)
        {
            return Ok(new
            {
                consumerId,
                optOut = DateTime.Now.Second % 2 == 0
            });
        }
    }
}
