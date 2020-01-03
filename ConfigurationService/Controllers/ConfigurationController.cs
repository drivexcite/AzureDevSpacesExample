using System;
using Microsoft.AspNetCore.Mvc;

namespace AzureDevSpacesExample.Controllers
{
    [ApiController]
    public class WeatherForecastController : ControllerBase
    {
        [HttpGet]
        [Route("settings/{memberId}")]
        public IActionResult GetOptOutSettings(string memberId)
        {
            return Ok(new
            {
                memberId,
                optOut = DateTime.Now.Second % 2 == 0
            });
        }
    }
}
