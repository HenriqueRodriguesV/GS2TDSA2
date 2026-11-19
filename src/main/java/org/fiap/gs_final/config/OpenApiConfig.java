package org.fiap.gs_final.config;

import io.swagger.v3.oas.annotations.OpenAPIDefinition;
import io.swagger.v3.oas.annotations.enums.SecuritySchemeType;
import io.swagger.v3.oas.annotations.info.Info;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.security.SecurityScheme;
import org.springframework.context.annotation.Configuration;

// O security global faz o Swagger UI enviar o token do botao "Authorize"
// (Authorization: Bearer ...) em todas as requisicoes. Rotas publicas, como o
// login, continuam liberadas pelo SecurityConfig.
@Configuration
@OpenAPIDefinition(
        info = @Info(
                title = "Refugio 360 API",
                version = "1.1.0",
                description = "API do Refugio 360 publicada na Azure via Azure DevOps"),
        security = @SecurityRequirement(name = "bearerAuth"))
@SecurityScheme(name = "bearerAuth", type = SecuritySchemeType.HTTP, scheme = "bearer", bearerFormat = "JWT")
public class OpenApiConfig {}
