using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using Dapr.Client;

namespace app1.Controllers
{
    [ApiController]
    public class HealthController : ControllerBase
    {
        [Route("health")]
        [HttpGet]
        public IActionResult Get()
        {
            var status = new
            {
                status = "OK"
            };

            return Ok(status);
        }

        [Route("healthapp2")]
        [HttpGet]
        public async Task<IActionResult> App2Get([FromServices] DaprClient daprClient)
        {
            var ext = new Dapr.Client.Http.HTTPExtension()
            {
                Verb = Dapr.Client.Http.HTTPVerb.Get,
            };

            var status = await daprClient.InvokeMethodAsync<object>("app2", "health", ext);

            return Ok(status);
        }
    }
}
