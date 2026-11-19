package org.fiap.gs_final.security;

import org.fiap.gs_final.model.Usuario;
import org.fiap.gs_final.repository.UsuarioRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.crypto.password.PasswordEncoder;

/**
 * Cria o gestor inicial a partir das variaveis GESTOR_EMAIL e GESTOR_PASSWORD.
 * Nenhuma senha fica no codigo: sem GESTOR_PASSWORD, o gestor nao e criado.
 */
@Configuration
public class GestorBootstrap {
    private static final Logger log = LoggerFactory.getLogger(GestorBootstrap.class);

    @Bean CommandLineRunner criarGestorInicial(UsuarioRepository repository, PasswordEncoder encoder,
            @Value("${app.bootstrap-gestor.email:gestor@refugio360.local}") String email,
            @Value("${app.bootstrap-gestor.password:}") String password) {
        return args -> {
            if (password == null || password.isBlank()) {
                log.warn("GESTOR_PASSWORD nao definida: gestor inicial nao foi criado.");
                return;
            }
            if (!repository.existsByEmailIgnoreCase(email)) repository.save(new Usuario(email.toLowerCase(), encoder.encode(password), "GESTOR"));
        };
    }
}
