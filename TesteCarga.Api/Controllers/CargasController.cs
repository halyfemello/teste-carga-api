using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace TesteCarga.Api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class CargasController : ControllerBase
    {

        public CargasController()
        {
        }

        [HttpGet("teste")]
        [ProducesResponseType(200)]
        public async Task<IActionResult> Teste()
        {
            var teste = new
            {
                Nome = "Teste",
                Data = DateTime.Now
            };

            return Ok(teste);
        }

        [HttpGet("teste2")]
        [ProducesResponseType(200)]
        public async Task<IActionResult> Teste2()
        {
            var teste = new
            {
                Nome = "Teste",
                Data = DateTime.Now
            };

            return Ok(teste);
        }

        [HttpGet("teste3")]
        [ProducesResponseType(200)]
        public async Task<IActionResult> Teste3()
        {
            var teste = new
            {
                Nome = "Teste",
                Data = DateTime.Now
            };

            return Ok(teste);
        }
    }
}