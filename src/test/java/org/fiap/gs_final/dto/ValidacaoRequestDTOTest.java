package org.fiap.gs_final.dto;

import jakarta.validation.ConstraintViolation;
import jakarta.validation.Validation;
import jakarta.validation.Validator;
import jakarta.validation.ValidatorFactory;
import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;

import java.util.Set;
import java.util.stream.Collectors;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

/** Regras de validacao das duas tabelas expostas no CRUD: locais seguros e pontos de risco. */
class ValidacaoRequestDTOTest {

    private static ValidatorFactory factory;
    private static Validator validator;

    @BeforeAll
    static void iniciar() {
        factory = Validation.buildDefaultValidatorFactory();
        validator = factory.getValidator();
    }

    @AfterAll
    static void encerrar() {
        factory.close();
    }

    private static Set<String> camposInvalidos(Set<? extends ConstraintViolation<?>> violacoes) {
        return violacoes.stream().map(v -> v.getPropertyPath().toString()).collect(Collectors.toSet());
    }

    @Test
    void localSeguroValidoNaoTemViolacoes() {
        var dto = new LocalSeguroRequestDTO("Abrigo Central", "ABRIGO", "Rua A, 100", -23.55, -46.63, "Entrada acessivel");
        assertTrue(validator.validate(dto).isEmpty());
    }

    @Test
    void localSeguroExigeNomeTipoEndereco() {
        var dto = new LocalSeguroRequestDTO(" ", "", null, -23.55, -46.63, null);
        assertEquals(Set.of("nome", "tipo", "endereco"), camposInvalidos(validator.validate(dto)));
    }

    @Test
    void localSeguroRecusaCoordenadasForaDoGlobo() {
        var dto = new LocalSeguroRequestDTO("Abrigo", "ABRIGO", "Rua A", -91.0, 181.0, null);
        assertEquals(Set.of("latitude", "longitude"), camposInvalidos(validator.validate(dto)));
    }

    @Test
    void pontoRiscoValidoAceitaNivelSemDiferenciarMaiusculas() {
        var dto = new PontoRiscoRequestDTO("Area sujeita a alagamento", "alto", -23.55, -46.63);
        assertTrue(validator.validate(dto).isEmpty());
    }

    @Test
    void pontoRiscoRecusaNivelDePerigoDesconhecido() {
        var dto = new PontoRiscoRequestDTO("Area de risco", "EXTREMO", -23.55, -46.63);
        assertEquals(Set.of("nivelPerigo"), camposInvalidos(validator.validate(dto)));
    }

    @Test
    void pontoRiscoExigeTituloECoordenadas() {
        var dto = new PontoRiscoRequestDTO("", "ALTO", null, null);
        assertEquals(Set.of("titulo", "latitude", "longitude"), camposInvalidos(validator.validate(dto)));
    }
}
