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

        [HttpGet("teste-erro")]
        [ProducesResponseType(200)]
        public async Task<IActionResult> TesteErro()
        {
            ModelState.AddModelError("Erro", "Erro de validação");
            return BadRequest(ModelState);
        }
    }
}