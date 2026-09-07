// lib/l10n/app_localizations_pt.dart
import 'dart:ui';
import 'app_localizations.dart';


class AppLocalizationsPt extends AppLocalizations {
    @override Locale get locale => const Locale('pt');
  // ============================================================================
  // COMMON & UI
  // ============================================================================
  @override String get common_back => 'Voltar';
  @override String get live_ending => 'Encerrando ao vivo';
  @override String get common_close => 'Fechar';
  @override String get common_cancel => 'Cancelar';
  @override String get common_confirm => 'Confirmar';
  @override String get common_delete => 'Excluir';
  @override String get common_add => 'Adicionar';
  @override String get common_edit => 'Editar';
  @override String get common_save => 'Salvar';
  @override String get common_manage => 'Gerenciar';
  @override String get common_retry => 'Tentar novamente';
  @override String get common_refresh => 'Atualizar';
  @override String get common_search => 'Pesquisar';
  @override String get common_open => 'Abrir';
  @override String get common_share => 'Compartilhar';
  @override String get common_copy => 'Copiar';
  @override String get common_copied => 'Copiado!';
  @override String get common_download => 'Baixar';
  @override String get common_upload => 'Enviar';
  @override String get common_send => 'Enviar';
  @override String get common_receive => 'Receber';
  @override String get common_accept => 'Aceitar';
  @override String get common_reject => 'Rejeitar';
  @override String get common_skip => 'Pular';
  @override String get common_next => 'Avançar';
  @override String get common_previous => 'Anterior';
  @override String get common_finish => 'Concluir';
  @override String get common_done => 'Feito';
  @override String get common_error => 'Erro';
  @override String get common_success => 'Sucesso';
  @override String get common_loading => 'Carregando…';
  @override String get common_please_wait => 'Por favor, aguarde…';
  @override String get common_today => 'Hoje';
  @override String get common_yesterday => 'Ontem';
  @override String get common_tomorrow => 'Amanhã';
  @override String get common_home => 'Início';
  @override String get common_chat => 'Bate-papo';
  @override String get common_map => 'Mapa';
  @override String get common_profile => 'Perfil';
  @override String get common_menu => 'Menu';
  @override String get common_notifications => 'Notificações';
  @override String get common_settings => 'Configurações';
  @override String get common_help => 'Ajuda';
  @override String get common_about => 'Sobre';
  @override String get common_logout => 'Sair';
  @override String get common_login => 'Entrar';
  @override String get common_signup => 'Cadastrar-se';
  @override String get common_yes => 'Sim';
  @override String get common_no => 'Não';
  @override String get common_or => 'ou';
  @override String get common_and => 'e';
  @override String get common_none => 'Nenhum';
  @override String get common_all => 'Todos';
  @override String get common_unknown => 'Desconhecido';
  @override String get common_enabled => 'Ativado';
  @override String get common_disabled => 'Desativado';
  @override String get common_clear => 'Limpar';
  @override String get common_remove => 'Remover';
  
  @override String common_items(int count) => count == 0 ? 'Nenhum item' : (count == 1 ? '1 item' : '$count itens');
  @override String common_contacts(int count) => count == 0 ? 'Nenhum contato' : (count == 1 ? '1 contato' : '$count contatos');
  @override String common_messages(int count) => count == 0 ? 'Nenhuma mensagem' : (count == 1 ? '1 mensagem' : '$count mensagens');
  @override String common_days(int count) => count == 0 ? '0 dias' : (count == 1 ? '1 dia' : '$count dias');
  @override String common_hours(int count) => count == 0 ? '0 horas' : (count == 1 ? '1 hora' : '$count horas');
  @override String common_minutes(int count) => count == 0 ? '0 minutos' : (count == 1 ? '1 minuto' : '$count minutos');

  // ============================================================================
  // AUTH & ONBOARDING (BASIC)
  // ============================================================================
  @override String get auth_login => 'Entrar';
  @override String get auth_signup => 'Cadastrar-se';
  @override String get auth_forgot_password => 'Esqueceu a senha?';
  @override String get auth_reset_password => 'Redefinir senha';
  @override String get auth_email => 'Endereço de e-mail';
  @override String get auth_phone => 'Número de telefone';
  @override String get auth_password => 'Senha';
  @override String get auth_confirm_password => 'Confirmar senha';
  @override String get auth_logout_confirm => 'Tem certeza de que deseja sair?';
  @override String get auth_welcome_back => 'Bem-vindo(a) de volta';
  @override String get auth_welcome => 'Bem-vindo(a)';
  @override String get auth_no_account => 'Ainda não tem uma conta?';
  @override String get auth_has_account => 'Já tem uma conta?';
  @override String get auth_invalid_email => 'Endereço de e-mail inválido';
  @override String get auth_invalid_phone => 'Número de telefone inválido';
  @override String get auth_password_too_short => 'A senha é muito curta (mín. 8 caracteres)';
  @override String get auth_passwords_mismatch => 'As senhas não coincidem';
  @override String get auth_login_success => 'Login realizado com sucesso';
  @override String get auth_signup_success => 'Conta criada com sucesso';
  @override String get auth_session_expired => 'Sessão expirada, faça login novamente';
  @override String get auth_2fa_title => 'Verificação em duas etapas';
  @override String get auth_2fa_code => 'Código de verificação';
  @override String get auth_verify_email => 'Verificar e-mail';
  @override String get auth_verify_phone => 'Verificar telefone';
  @override String get auth_biometric => 'Login biométrico';
  @override String get auth_biometric_prompt => 'Autentique-se para continuar';
  @override String get auth_full_name => 'Nome completo';
  @override String get auth_first_name => 'Nome';
  @override String get auth_last_name => 'Sobrenome';
  @override String get auth_birth_date => 'Data de nascimento';
  @override String get auth_gender => 'Gênero';
  @override String get auth_gender_male => 'Masculino';
  @override String get auth_gender_female => 'Feminino';
  @override String get auth_gender_other => 'Outro';
  @override String get auth_accept_terms => 'Eu aceito os Termos de Uso';
  @override String get auth_terms_required => 'Você deve aceitar os termos';
  @override String get auth_email_already_used => 'Este e-mail já está em uso';
  @override String get auth_phone_already_used => 'Este número de telefone já está em uso';
  @override String get auth_create_account => 'Criar minha conta';
  @override String get auth_already_have_account => 'Já tenho uma conta';

  @override String get onboarding_welcome => 'Bem-vindo(a) ao THIX';
  @override String get onboarding_step_1_title => 'Conectar';
  @override String get onboarding_step_1_desc => 'Crie sua identidade segura no THIX';
  @override String get onboarding_step_2_title => 'Proteção';
  @override String get onboarding_step_2_desc => 'Ative a proteção 24/7';
  @override String get onboarding_step_3_title => 'Ação';
  @override String get onboarding_step_3_desc => 'Alerte o socorro em 2 segundos';
  @override String get onboarding_get_started => 'Começar';
  @override String get onboarding_skip => 'Pular introdução';

  // ============================================================================
  // AUTHENTIFICATION & CONNEXION (ADVANCED / ERRORS)
  // ============================================================================
  @override String get login_title => 'Entrar no THIX';
  @override String get login_subtitle => 'Bem-vindo(a) de volta';
  @override String get login_identifier_label => 'Identificador';
  @override String get login_identifier_hint => 'E-mail, telefone ou THIX ID';
  @override String get login_password_label => 'Senha';
  @override String get login_password_hint => 'Sua senha segura';
  @override String get login_remember_me => 'Lembrar de mim';
  @override String get login_forgot_password => 'Esqueceu a senha?';
  @override String get login_button => 'Entrar';
  @override String get login_verifying => 'Verificando…';
  @override String get login_retry_in => 'Tente novamente em';
  @override String get login_seconds_suffix => 's';
  @override String get login_biometric => 'OU CONTINUAR COM';
  @override String get login_face_id => 'Face ID';
  @override String get login_touch_id => 'Touch ID';
  
  @override String get login_error_suspended => 'Esta conta está suspensa. Contate o suporte.';
  @override String get login_error_not_active => 'Esta conta não está ativada.';
  @override String get login_error_no_account => 'Nenhuma conta encontrada com esses dados.';
  @override String get login_error_mfa_required => 'Verificação em duas etapas obrigatória.';

  @override String get auth_error_identifier_required => 'O identificador é obrigatório';
  @override String get auth_error_password_required => 'A senha é obrigatória';
  @override String get auth_error_thix_id_login_not_available => 'O login por THIX ID não está disponível no momento';
  @override String get auth_error_sign_in_failed => 'Falha no login. Verifique suas credenciais.';
  @override String get auth_error_email_not_verified => 'Verifique seu e-mail antes de fazer login';
  @override String get auth_error_server_misconfiguration => 'Erro de configuração do servidor';
  @override String get auth_error_account_already_exists => 'Já existe uma conta com este identificador';
  @override String get auth_error_account_exists_wrong_password => 'Esta conta existe, mas a senha está incorreta';
  @override String get auth_error_account_exists_new_otp_sent => 'Um novo código OTP foi enviado para o seu endereço';
  @override String get auth_error_invalid_otp => 'Código OTP inválido ou expirado';
  @override String get auth_error_otp_expired => 'O código OTP expirou';
  @override String get auth_error_network => 'Erro de conexão. Verifique sua internet.';
  @override String get auth_error_rate_limit => 'Muitas tentativas. Aguarde um momento.';
  @override String get auth_error_technical => 'Ocorreu um erro técnico. Tente novamente.';
  @override String get auth_error_user_mismatch => 'Incompatibilidade de usuário detectada';
  @override String get auth_error_profile_update_failed => 'Falha ao atualizar o perfil';
  @override String get auth_error_mark_email_verified_failed => 'Falha ao verificar o e-mail';
  @override String get auth_error_qr_token_generation_failed => 'Falha ao gerar o token QR';
  @override String get auth_error_finalize_registration_failed => 'Falha ao finalizar o cadastro';
  @override String get auth_error_consume_qr_token_failed => 'Falha ao consumir o token QR';
  @override String get auth_error_resend_otp_failed => 'Falha ao reenviar o código OTP';
  @override String get auth_error_phone_auth_not_available => 'A autenticação por telefone não está disponível';
  @override String get auth_error_delete_account_not_available => 'A exclusão de conta não está disponível no momento';
  @override String get auth_error_update_email_failed => 'Falha ao atualizar o endereço de e-mail';
  @override String get auth_error_reset_password_failed => 'Falha ao redefinir a senha';
  @override String get auth_error_sign_up_failed => 'Falha ao criar a conta';
  @override String get auth_info_otp_sent => 'Um código de verificação foi enviado';

  // ============================================================================
  // INSCRIPTION PERSONNELLE (PERSONAL REGISTRATION)
  // ============================================================================
  @override String get reg_step1_title => 'Seu perfil';
  @override String get reg_step1_subtitle => 'Vamos começar com as informações básicas';
  @override String get reg_full_name_label => 'Nome completo';
  @override String get reg_full_name_hint => 'Nome e Sobrenome';
  @override String get reg_dob_label => 'Data de nascimento';
  @override String get reg_country_label => 'País de residência';
  @override String get reg_occupation_label => 'Profissão / Atividade';
  @override String get reg_occupation_hint => 'Ex: Desenvolvedor, Estudante, Empreendedor';
  @override String get reg_next => 'Avançar';

  @override String get reg_step2_title => 'Proteja sua conta';
  @override String get reg_step2_subtitle => 'Crie suas credenciais de acesso';
  @override String get reg_email_label => 'Endereço de e-mail';
  @override String get reg_email_hint => 'seu.email@exemplo.com';
  @override String get reg_phone_label => 'Número de telefone';
  @override String get reg_phone_hint => '+55 11 9XXXX-XXXX';
  @override String get reg_password_label => 'Senha';
  @override String get reg_password_hint => 'Mínimo de 8 caracteres';
  @override String get reg_confirm_password_label => 'Confirmar senha';
  @override String get reg_confirm_password_hint => 'Digite a senha novamente';
  @override String get reg_strength_label => 'Força da senha';
  @override String get reg_strength_very_weak => 'Muito fraca';
  @override String get reg_strength_weak => 'Fraca';
  @override String get reg_strength_medium => 'Média';
  @override String get reg_strength_strong => 'Forte';
  @override String get reg_strength_excellent => 'Excelente';

  @override String get reg_identity_title => 'Identidade THIX';
  @override String get reg_thix_chat_label => 'Nome de usuário no THIX Chat';
  @override String get reg_thix_chat_hint => 'Ex: joao.silva (único)';
  
  @override String get reg_verification_title => 'Verificação';
  @override String get reg_get_otp => 'Receber código de verificação';
  @override String get reg_code_sent_resend => 'Reenviar código';
  @override String get reg_resend_in => 'Reenviar em';
  @override String get reg_seconds_short => 's';
  @override String get reg_otp_label => 'Código de Verificação (OTP)';
  @override String get reg_validate_activate => 'Verificar e ativar';
  @override String get reg_activating => 'Ativando…';

  @override String get reg_congrats => 'Parabéns!';
  @override String get reg_welcome_message => 'Bem-vindo(a) ao ecossistema THIX,';
  @override String get reg_id_card_title => 'CARTEIRA DE IDENTIDADE DIGITAL THIX';
  @override String get reg_official_thix_id => 'THIX ID OFICIAL';
  @override String get reg_generating => 'Gerando…';
  @override String get reg_copy_thix_id => 'Copiar THIX ID';
  @override String get reg_thix_id_copied => 'THIX ID copiado para a área de transferência';
  @override String get reg_go_to_dashboard => 'Ir para o Painel';
  @override String get reg_summary => 'Resumo do Cadastro';
  @override String get reg_mobile_label => 'Celular';
  @override String get reg_not_provided => 'Não informado';

  // ============================================================================
  // ACCUEIL & TABLEAU DE BORD (HOME & DASHBOARD)
  // ============================================================================
  @override String get home_search_hint => 'Pesquisar um serviço ou contato…';
  @override String get home_greeting => 'Olá';
  @override String get home_greeting_time => 'Boa noite';
  @override String get home_welcome_back => 'Bem-vindo(a) de volta';
  @override String get home_language_kiswahili => 'Kiswahili';
  @override String get home_banner_default_tag => 'PROGRAMA PARA JOVENS';
  @override String get home_banner_default_title => 'Descubra as últimas oportunidades e eventos';
  
  @override String get cert_pending => 'Certificação pendente';
  @override String get cert_tier_ladder => 'Nível atualmente sob revisão';
  @override String get cert_view => 'Ver';

  @override String get quick_sona => 'THIX Sona';
  @override String get quick_doc => 'Meus documentos';
  @override String get quick_chat => 'Bate-papo';
  @override String get quick_sos => 'Emergência';
  @override String get service_sante => 'THIX Saúde';
  @override String get service_market => 'Mercado THIX';
  @override String get service_money => 'Carteira THIX';
  @override String get service_reservation => 'Reservas';
  @override String get service_mon_pays => 'Meu País';
  @override String get service_emploi => 'Empregos';
  @override String get service_formations => 'Treinamentos';
  @override String get service_opportunites => 'Oportunidades';
  @override String get service_infos => 'Notícias';
  @override String get service_events => 'Eventos';
  @override String get service_media => 'THIX Mídia';
  @override String get service_vault => 'Cofre';
  @override String get service_network => 'Rede';
  @override String get service_certification => 'Certificação';

    @override String get live_go_live => 'Iniciar Transmissão';
  @override String get live_title => 'Título da Transmissão';
  @override String get live_start => 'Começar';
  @override String get live_end => 'Encerrar';
  @override String get live_duration => 'Duração';
  @override String get live_peak_viewers => 'Pico de Espectadores';
  @override String get live_chat_disabled => 'O chat está desativado.';
  @override String get live_share => 'Compartilhar';
  @override String get live_report => 'Denunciar';
  @override String get live_follow_host => 'Seguir';
  @override String get live_gift_send => 'Enviar Presente';
  @override String get live_quality_auto => 'Automático';
  @override String get live_quality_hd => 'HD';
  @override String get live_quality_sd => 'SD';
  @override String get live_quality_low => 'Baixa';

  @override String get insight_source_unverified => 'Fonte não verificada';
  @override String get insight_recommended_actions => 'Ações recomendadas';
  @override String get insight_key_findings => 'Principais descobertas';
  @override String get insight_summary => 'Resumo';
  @override String get insight_full_analysis => 'Análise Completa';
  @override String get insight_generated_by => 'Gerado por IA';
  @override String get insight_disclaimer => 'Esta é uma análise gerada por IA. Por favor, verifique as informações.';

  @override String get risk_level_label => 'Nível de Risco';
  @override String get risk_mitigation => 'Mitigação';
  @override String get risk_impact => 'Impacto';
  @override String get risk_probability => 'Probabilidade';
  @override String get risk_assessment => 'Avaliação de Risco';


  // ============================================================================
  // CHAT & MESSAGERIE (CHAT & MESSAGING)
  // ============================================================================
  @override String get chatlist_network => 'Rede';
  @override String get chatlist_discussions => 'Conversas';
  @override String get chatlist_create_new => 'Criar nova conversa';
  @override String get chatlist_calls => 'Chamadas';
  @override String get chatlist_settings => 'Configurações';

  @override String get chat_unknown_user => 'Usuário desconhecido';
  @override String chat_members(int count) => count == 1 ? '1 membro' : '$count membros';
  @override String get chat_video_call => 'Chamada de vídeo';
  @override String get chat_audio_call => 'Chamada de áudio';
  @override String get chat_escalate => 'Escalar';
  @override String get chat_history => 'Histórico';
  @override String get chat_group_info => 'Info do grupo';
  @override String get chat_file => 'Arquivo';
  @override String get chat_sticker => 'Adesivo';
  @override String get chat_ephemeral => 'Temporária';
  @override String get chat_protected => 'Protegido';
  @override String get chat_internal_note => 'Nota interna';
  @override String get chat_send => 'Enviar';
  @override String get chat_recording => 'Gravando';
  @override String get chat_stop_recording => 'Parar';
  @override String get chat_write_message => 'Escreva uma mensagem...';
  @override String get chat_record_audio => 'Gravar áudio';
  @override String get chat_emojis => 'Emojis';
  @override String get chat_reactions => 'Reações';
  @override String get chat_flags => 'Sinalizações';
  @override String get chat_callback => 'Retornar ligação';
  @override String get chat_typing => 'está digitando...';
  @override String get chat_pause => 'Pausar';
  @override String get chat_play => 'Reproduzir';

  @override String get conv_status_connected => 'Conectado';
  @override String get conv_status_pending => 'Pendente';
  @override String get conv_status_rejected => 'Rejeitado';
  @override String get conv_cannot_self => 'Você não pode adicionar a si mesmo';
  @override String get conv_request_pending => 'Pedido de conexão pendente';
  @override String get conv_request_rejected => 'Pedido de conexão rejeitado';
  @override String get conv_request_to => 'Enviar pedido para';
  @override String get conv_request_hint => 'Adicione uma mensagem opcional ao seu pedido de conexão.';
  @override String get conv_message_optional => 'Mensagem (opcional)';
  @override String get conv_send_request => 'Enviar pedido';
  @override String get conv_request_sent => 'Pedido enviado com sucesso';
  @override String get conv_request_exists => 'Já existe um pedido para este usuário';
  @override String get conv_select_contact => 'Por favor, selecione pelo menos um contato';
  @override String get conv_waiting_connection => 'Aguardando conexão para';
  @override String get conv_group_rpc_required => 'A criação de grupo requer uma chamada de servidor';
  @override String get conv_page_title => 'Nova conversa';
  @override String conv_start(int count) => 'Iniciar ($count)';
  @override String get conv_search_label => 'Pesquisar usuário';
  @override String get conv_search_hint => 'Nome, THIX ID ou número de telefone...';
  @override String get conv_group_name_label => 'Nome do grupo';
  @override String get conv_group_name_hint => 'Ex: Equipe Projeto Alpha';

  @override String get requests_page_title => 'Pedidos de Conexão';
  @override String get requests_reject_title => 'Rejeitar pedido';
  @override String get requests_reject_message => 'Tem certeza de que deseja rejeitar este pedido de conexão? Esta ação é irreversível.';
  @override String get requests_reject_confirm => 'Rejeitar';
  @override String get requests_rejected => 'Pedido rejeitado';
  @override String get requests_reject_error => 'Erro ao rejeitar o pedido';
  @override String get requests_accepted => 'Pedido aceito com sucesso';
  @override String get requests_accept_error => 'Erro ao aceitar o pedido';

  @override String get call_history_title => 'Histórico de Chamadas';
  @override String get call_missed => 'Chamada perdida';
  @override String get call_incoming => 'Chamada recebida';
  @override String get call_outgoing => 'Chamada efetuada';
  @override String get call_video => 'Chamada de vídeo';
  @override String get call_audio => 'Chamada de áudio';

  // ============================================================================
  // RÉSEAU SOCIAL (NETWORK)
  // ============================================================================
  @override String get network_search_title => 'Pesquisar';
  @override String get network_search_hint => 'Pesquise pessoas, postagens ou comunidades…';
  @override String get network_tab_people => 'Pessoas';
  @override String get network_tab_posts => 'Postagens';
  @override String get network_tab_communities => 'Comunidades';
  @override String get network_explore_title => 'Explore a Rede THIX';
  @override String get network_explore_subtitle => 'Pesquise pessoas, postagens ou comunidades';
  @override String get network_no_results_users => 'Nenhum usuário encontrado';
  @override String get network_no_results_posts => 'Nenhuma postagem encontrada';
  @override String get network_no_results_communities => 'Nenhuma comunidade encontrada';
  @override String get network_request_sent => 'Pedido enviado para';
  @override String get network_request_error => 'Erro ao enviar o pedido';

  @override String get community_create_title => 'Criar uma comunidade';
  @override String get community_name_label => 'Nome da comunidade';
  @override String get community_description_label => 'Descrição';
  @override String get community_visibility_label => 'Visibilidade';
  @override String get community_public => 'Pública';
  @override String get community_private => 'Privada';
  @override String get community_join => 'Entrar';
  @override String get community_leave => 'Sair';
  @override String get community_members => 'membros';
  @override String get community_admin => 'Administrador';

  // ============================================================================
  // PROFIL UTILISATEUR (PROFILE)
  // ============================================================================
  @override String get profile_settings => 'Configurações do perfil';
  @override String get profile_edit_bio => 'Editar Bio';
  @override String get profile_no_bio => 'Nenhuma biografia disponível no momento.';
  @override String get profile_followers => 'Seguidores';
  @override String get profile_following => 'Seguindo';
  @override String get profile_posts => 'Postagens';
  @override String get profile_follow => 'Seguir';
  @override String get profile_unfollow => 'Seguindo';
  @override String get profile_following_loading => 'Carregando…';
  @override String get profile_message => 'Mensagem';
  @override String get profile_block_user => 'Bloquear este usuário?';
  @override String get profile_block_message => 'Você não verá mais as postagens dele e ele não poderá interagir com você.';
  @override String get profile_block_confirm => 'Bloquear';
  @override String get profile_blocked_success => 'Usuário bloqueado';
  @override String get profile_block_error => 'Erro ao bloquear';
  
  @override String get profile_report_user => 'Denunciar';
  @override String get profile_report_reason => 'Motivo';
  @override String get profile_report_details => 'Detalhes (opcional)';
  @override String get profile_report_spam => 'Spam';
  @override String get profile_report_inappropriate => 'Conteúdo inadequado';
  @override String get profile_report_harassment => 'Assédio';
  @override String get profile_report_impersonation => 'Falsidade ideológica';
  @override String get profile_report_other => 'Outro';
  @override String get profile_report_submit => 'Enviar denúncia';
  @override String get profile_report_success => 'Denúncia enviada';
  @override String get profile_report_duplicate => 'Já denunciado';
  
  @override String get profile_private_gallery => 'Galeria privada';
  @override String get profile_private_content_locked => 'Este conteúdo é privado';
  @override String get profile_add_private_media => 'Adicionar à minha galeria privada';
  @override String get profile_no_private_media => 'Nenhuma mídia privada ainda';
  @override String get profile_upload_processing => 'Processando…';
  
  @override String get profile_tab_bio => 'Bio';
  @override String get profile_tab_private_gallery => 'Galeria Privada';
  @override String get profile_tab_photos => 'Fotos Públicas';
  @override String get profile_tab_videos => 'Vídeos';
  @override String get profile_tab_audios => 'Áudios';
  @override String get profile_no_content => 'Nenhum conteúdo';
  @override String get profile_pinned_post => 'Postagem Fixada';
  @override String get profile_view_post => 'Ver postagem';

  // ============================================================================
  // PARAMÈTRES GÉNÉRAUX & CHAT (SETTINGS)
  // ============================================================================
  @override String get settings_title => 'Configurações de bate-papo';
  @override String get settings_section_appearance => 'Aparência';
  @override String get settings_theme => 'Tema';
  @override String get settings_theme_light => 'Claro';
  @override String get settings_theme_dark => 'Escuro';
  @override String get settings_theme_system => 'Padrão do sistema';
  @override String get settings_wallpaper => 'Papel de parede';
  @override String get settings_wallpaper_default => 'Padrão';
  @override String get settings_wallpaper_custom => 'Personalizado';
  
  @override String get settings_section_privacy => 'Privacidade';
  @override String get settings_last_seen => 'Visto por último';
  @override String get settings_visibility_everyone => 'Todos';
  @override String get settings_visibility_contacts => 'Meus contatos';
  @override String get settings_visibility_nobody => 'Ninguém';
  @override String get settings_profile_photo => 'Foto de perfil';
  
  @override String get settings_section_notifications => 'Notificações';
  @override String get settings_messages => 'Mensagens';
  @override String get settings_calls => 'Chamadas';
  
  @override String get settings_section_messages => 'Dados e Armazenamento';
  @override String get settings_ephemeral => 'Mensagens temporárias';
  @override String get settings_auto_download => 'Download automático de mídia';
  @override String get settings_download_wifi => 'Somente Wi-Fi';
  @override String get settings_download_mobile => 'Wi-Fi e Dados Celulares';
  @override String get settings_download_never => 'Nunca';
  
  @override String get settings_section_account => 'Conta';
  @override String get settings_view_profile => 'Ver meu perfil';
  @override String get settings_logout => 'Sair';

  @override String get settings_profile_edit => 'Editar perfil';
  @override String get settings_notifications => 'Notificações';
  @override String get settings_privacy => 'Privacidade';
  @override String get settings_security => 'Segurança';
  @override String get settings_language => 'Idioma';
  @override String get settings_help_center => 'Central de Ajuda';
  @override String get settings_about => 'Sobre o THIX';
  @override String get settings_version => 'Versão';

  // ============================================================================
  // TRADUCTIONS DE LANGUAGE SHEET
  // ============================================================================
  @override String get settings_choose_language => 'Escolha o Idioma';
  @override String get settings_system_default => 'Padrão do sistema';
  @override String get settings_language_change_failed => 'Falha ao alterar o idioma';

  // ============================================================================
  // SOS & URGENCE (EMERGENCY)
  // ============================================================================
  @override String get sos_button => 'Emergência';
  @override String get sos_button_label => 'Botão de Emergência SOS';
  @override String get sos_button_hint => 'Segure por 2 segundos para ativar';
  @override String get sos_button_tooltip => 'Pressione e segure por 2 segundos';
  @override String get sos_trigger_button => 'Ativar SOS';
  @override String get sos_trigger_timeout => 'O pedido expirou. Tente novamente.';
  @override String get sos_trigger_error => 'Falha ao ativar o SOS';
  @override String get sos_active => 'SOS Ativo';
  @override String get sos_crisis_room => 'Sala de Crise';
  @override String get sos_command_center => 'Centro de Comando';
  @override String get sos_incident => 'Incidente';
  @override String get sos_incident_unknown => 'Incidente desconhecido';
  @override String get sos_incident_not_found => 'Incidente não encontrado';
  @override String get sos_circle => 'Círculo';
  @override String get sos_rescuers => 'Socorristas';
  @override String get sos_rescuer => 'Socorrista';
  @override String get sos_my_rescuers => 'Meus socorristas';
  @override String get sos_duration => 'Duração';
  @override String get sos_identifier => 'Identificador';
  @override String get sos_calling => 'Ligando…';
  @override String get sos_call => 'Ligar';
  @override String get sos_available => 'Disponível';
  @override String get sos_unavailable => 'Indisponível';
  @override String get sos_verified => 'Verificado';
  @override String get sos_end => 'Encerrar';
  @override String get sos_end_sos => 'Encerrar SOS';
  @override String get sos_cancel_sos => 'Cancelar SOS';
  @override String get sos_pin_required => 'PIN de segurança obrigatório';
  @override String get sos_cancelled => 'SOS Cancelado';
  @override String get sos_resolved => 'SOS Resolvido';
  @override String get sos_cancel_failed => 'Falha ao cancelar';
  @override String get sos_in_progress => 'Em andamento';
  @override String get sos_history => 'Histórico';
  @override String get sos_my_incidents => 'Meus incidentes';
  @override String get sos_no_incidents => 'Nenhum incidente ainda';
  @override String get sos_incidents_appear_here => 'Seus pedidos de SOS aparecerão aqui';
  @override String get sos_history_error => 'Falha ao carregar histórico';
  @override String get sos_circle_1 => 'Círculo 1 – Prioridade';
  @override String get sos_circle_2 => 'Círculo 2 – Secundário';
  @override String get sos_circle_3 => 'Círculo 3 – Emergência';
  @override String get sos_no_rescuers => 'Nenhum socorrista';
  @override String get sos_add_first_rescuer => 'Adicione seu primeiro contato de emergência';
  @override String get sos_add_rescuer => 'Adicionar socorrista';
  @override String get sos_add_rescuer_info => 'Digite o THIX ID do socorrista. O nome e a foto serão buscados automaticamente.';
  @override String get sos_thix_id_label => 'THIX ID';
  @override String get sos_thix_id_hint => 'THIX-XXXX';

  // ============================================================================
  // CERTIFICATION
  // ============================================================================
  @override String get certification_title => 'Certificação THIX';
  @override String get certification_apply => 'Solicitar certificação';
  @override String get certification_status => 'Status';
  @override String get certification_pending => 'Pendente';
  @override String get certification_approved => 'Aprovado';
  @override String get certification_rejected => 'Rejeitado';
  @override String get certification_tier_bronze => 'Bronze';
  @override String get certification_tier_silver => 'Prata';
  @override String get certification_tier_gold => 'Ouro';
  @override String get certification_tier_platinum => 'Platina';
  @override String get certification_benefits => 'Benefícios';
  @override String get certification_documents => 'Documentos obrigatórios';
  @override String get certification_upload_doc => 'Enviar documento';
  @override String get certification_review_progress => 'Em análise';
  @override String get certification_verified_account => 'Conta Verificada';

  // ============================================================================
  // ÉDUCATION & FORMATION (EDUCATION & TRAINING)
  // ============================================================================
  @override String get edu_nav_home => 'Início';
  @override String get edu_nav_learning => 'Minha Aprendizagem';
  @override String get edu_nav_library => 'Biblioteca';
  @override String get edu_nav_certs => 'Certificados';
  @override String get edu_nav_profile => 'Perfil';
  
  @override String get edu_auth_required => 'Faça login para ver seus cursos';
  @override String get edu_login_required => 'Faça login para ver seus cursos';
  
  @override String get edu_learning_empty_title => 'Nenhum curso em andamento';
  @override String get edu_learning_empty_desc => 'Inscreva-se em um curso para começar.';
  @override String get edu_no_courses => 'Nenhum curso em andamento';
  @override String get edu_enroll_hint => 'Inscreva-se em um curso para começar.';
  @override String get edu_explore_btn => 'Explorar cursos';
  @override String get edu_completed => 'Concluído';
  
  @override String get edu_user_avatar => 'Avatar do Usuário';
  @override String get edu_greeting => 'Olá,';
  @override String get edu_greeting_subtitle => 'Pronto para melhorar suas habilidades?';
  @override String get edu_ready_to_learn => 'Pronto para melhorar suas habilidades?';
  @override String get edu_learner => 'Aprendiz';
  @override String get edu_notifications => 'Notificações';
  @override String get edu_search_hint => 'Pesquisar cursos, certificações…';
  @override String get edu_browse => 'Navegar';
  @override String get edu_library => 'Biblioteca';
  @override String get edu_certs => 'Certificados';
  @override String get edu_qa_browse => 'Navegar';
  @override String get edu_instructor => 'Instrutor';
  
  @override String get edu_top_formations => 'Principais Cursos';
  @override String get edu_awaited_formations => 'Mais Aguardados';
  @override String get edu_awaited => 'Mais Aguardados';
  @override String get edu_see_all => 'Ver Catálogo';
  
  @override String edu_coming_soon(String category) => 'Novos cursos de $category em breve';
  @override String get edu_coming_soon_cat => 'Novos cursos em breve aqui';
  @override String get edu_locked_course => 'Em breve! (Abertura prevista em breve)';
  @override String get edu_coming_soon_badge => 'ABERTURA EM BREVE';
  @override String get edu_awaited_badge => 'Em Breve';
  @override String get edu_awaited_locked => 'Bloqueado';
  @override String get edu_awaited_locked_msg => 'Em breve! (Abertura prevista em breve)';
  
  @override String get edu_thix_academy => 'THIX Academy';
  @override String get edu_scheduled_soon => 'Agendado para: Em breve';
  @override String get edu_new_program => 'NOVO PROGRAMA';
  @override String get edu_resume_learning => 'RETOMAR APRENDIZAGEM';
  @override String get edu_resume => 'Retomar aprendizagem';
  
  @override String get edu_catalog => 'Catálogo';
  @override String get edu_no_formations_cat => 'Nenhum curso nesta categoria';
  
  @override String get edu_my_library => 'Minha Biblioteca';
  @override String get edu_search_book_hint => 'Pesquisar por título ou autor...';
  @override String get edu_library_title => 'Minha biblioteca';
  @override String get edu_search_library => 'Pesquisar por título ou autor…';
  @override String get edu_shelves_empty => 'Suas prateleiras estão vazias.';
  @override String get edu_library_empty => 'Suas prateleiras estão vazias.';
  @override String get edu_no_result => 'Sem resultados';
  @override String edu_search_no_results(String query) => 'Nenhum resultado para "$query"';
  
  @override String get edu_shelf => 'Prateleira';
  @override String get edu_books => 'livros';
  @override String get edu_all => 'Todos';
  @override String edu_shelf_info(String code, int count) => 'Prateleira $code · $count livros';
  @override String get edu_free => 'Grátis';
  @override String get edu_deleted_in => 'Não estará mais acessível em';
  @override String edu_expires_in(String countdown) => 'Expira em $countdown';
  
  @override String get edu_certifications => 'Certificações';
  @override String get edu_certs_title => 'Certificações';
  @override String get edu_no_certs => 'Nenhuma certificação ainda';
  @override String get edu_cert_expert => 'Certificado de Especialidade';
  @override String get edu_cert_expertise => 'Certificado de Especialidade';
  @override String edu_cert_issued(String date) => 'Emitido em $date';
  
  @override String get edu_pro_account => 'Conta Profissional';
  @override String get edu_profile_title => 'Conta Profissional';
  @override String get edu_instructor_space => 'Painel do Instrutor';
  @override String get edu_tools => 'Ferramentas Institucionais';
  @override String get edu_institutional_tools => 'Ferramentas Institucionais';
  @override String get edu_free_resources => 'Recursos Abertos';
  @override String get edu_masterclass => 'Masterclasses';
  @override String get edu_masterclasses => 'Masterclasses';
  @override String get edu_network => 'Rede e Mentoria';
  @override String get edu_mentorship => 'Networking e Mentoria';
  @override String get edu_events_agenda => 'Agenda de Eventos';
  @override String get edu_support => 'Suporte Técnico';
  @override String get edu_not_connected => 'Não conectado';

  @override String get training_title => 'Treinamento';
  @override String get training_enroll => 'Inscrever-se';
  @override String get training_my_courses => 'Meus Cursos';
  @override String get training_certificates => 'Meus Certificados';
  @override String get training_progress => 'Progresso';
  @override String get training_lessons => 'Lições';
  @override String get training_duration => 'Duração';
  @override String get training_level => 'Nível';
  @override String get training_beginner => 'Iniciante';
  @override String get training_intermediate => 'Intermediário';
  @override String get training_advanced => 'Avançado';
  @override String get training_start_course => 'Iniciar Curso';
  @override String get training_continue_course => 'Continuar Curso';

  // ============================================================================
  // EMPLOIS & RECRUTEMENT (JOBS & RECRUITING)
  // ============================================================================
  @override String get jobs_title => 'Vagas';
  @override String get jobs_search => 'Pesquisar Vagas';
  @override String get jobs_apply => 'Candidatar-se';
  @override String get jobs_saved => 'Salvas';
  @override String get jobs_applied => 'Candidaturas Enviadas';
  @override String get jobs_company => 'Empresa';
  @override String get jobs_location => 'Localização';
  @override String get jobs_salary => 'Salário';
  @override String get jobs_type => 'Tipo';
  @override String get jobs_full_time => 'Tempo Integral';
  @override String get jobs_part_time => 'Meio Período';
  @override String get jobs_contract => 'Contrato';
  @override String get jobs_internship => 'Estágio';
  @override String get jobs_freelance => 'Autônomo';
  @override String get jobs_remote => 'Remoto';
  @override String get jobs_onsite => 'Presencial';
  @override String get jobs_hybrid => 'Híbrido';
  @override String get jobs_experience => 'Experiência';
  @override String get jobs_no_experience => 'Nível Básico';
  @override String get jobs_junior => 'Júnior';
  @override String get jobs_mid => 'Pleno';
  @override String get jobs_senior => 'Sênior';
  @override String get jobs_requirements => 'Requisitos';
  @override String get jobs_responsibilities => 'Responsabilidades';
  @override String get jobs_benefits => 'Benefícios';
  @override String get jobs_apply_now => 'Candidatar-se Agora';
  @override String get jobs_application_sent => 'Candidatura Enviada';
  @override String get jobs_no_results => 'Nenhuma vaga encontrada';
  @override String get recruiter_title => 'Recrutador';
  @override String get recruiter_post_job => 'Publicar Vaga';
  @override String get recruiter_candidates => 'Candidatos';
  @override String get recruiter_applications => 'Candidaturas';
  @override String get recruiter_interviews => 'Entrevistas';

  // ============================================================================
  // OPPORTUNITÉS (OPPORTUNITIES)
  // ============================================================================
  @override String get opportunities_title => 'Oportunidades';
  @override String get opportunities_business => 'Negócios';
  @override String get opportunities_investment => 'Investimento';
  @override String get opportunities_partnership => 'Parceria';
  @override String get opportunities_grant => 'Bolsa / Subsídio';
  @override String get opportunities_coming_soon => 'Em breve';

  // ============================================================================
  // MARCHÉ & E-COMMERCE (MARKET)
  // ============================================================================
  @override String get market_title => 'Mercado THIX';
  @override String get market_categories => 'Categorias';
  @override String get market_products => 'Produtos';
  @override String get market_services => 'Serviços';
  @override String get market_add_to_cart => 'Adicionar ao Carrinho';
  @override String get market_buy_now => 'Comprar Agora';
  @override String get market_cart => 'Carrinho';
  @override String get market_checkout => 'Finalizar Compra';
  @override String get market_total => 'Total';
  @override String get market_delivery => 'Entrega';
  @override String get market_seller => 'Vendedor';
  @override String get market_rating => 'Avaliação';
  @override String get market_reviews => 'Revisões';
  @override String get market_in_stock => 'Em Estoque';
  @override String get market_out_of_stock => 'Esgotado';
  @override String get market_add_to_favorites => 'Adicionar aos Favoritos';
  @override String get market_remove_from_cart => 'Remover do Carrinho';

  // ============================================================================
  // PORTEFEUILLE & ARGENT (WALLET & MONEY)
  // ============================================================================
  @override String get money_title => 'Carteira THIX';
  @override String get money_balance => 'Saldo';
  @override String get money_send => 'Enviar';
  @override String get money_receive => 'Receber';
  @override String get money_history => 'Histórico';
  @override String get money_transactions => 'Transações';
  @override String get money_top_up => 'Recarregar';
  @override String get money_withdraw => 'Sacar';
  @override String get money_transfer => 'Transferir';
  @override String get money_bills => 'Contas';
  @override String get money_recipients => 'Beneficiários';
  @override String get money_add_recipient => 'Adicionar um beneficiário';
  @override String get money_amount => 'Valor';
  @override String get money_fee => 'Taxa';
  @override String get money_reference => 'Referência';
  @override String get money_confirm_transfer => 'Confirmar Transferência';
  @override String get money_transfer_success => 'Transferência Concluída';
  @override String get money_transfer_failed => 'Falha na Transferência';
  @override String get money_insufficient_funds => 'Saldo Insuficiente';

  // ============================================================================
  // ÉVÉNEMENTS & BILLETS (EVENTS & TICKETS)
  // ============================================================================
  @override String get events_title => 'Eventos';
  @override String get events_upcoming => 'Próximos';
  @override String get events_past => 'Passados';
  
  @override String get event_share_cta => 'Garanta seu lugar no THIX!';
  @override String get event_sold_out_title => 'Evento Esgotado';
  @override String get event_sold_out_msg => 'Todas as vagas estão ocupadas no momento. Entre na fila de espera para ser notificado se surgirem vagas.';
  @override String get event_join_queue_confirm => 'Deseja entrar na lista de espera?';
  @override String get event_join_queue_btn => 'Entrar na fila';
  
  @override String get event_unfavorite => 'Remover dos favoritos';
  @override String get event_favorite => 'Adicionar aos favoritos';
  @override String get event_free => 'Grátis';
  @override String get event_paid => 'Pago';
  
  @override String get event_time_label => 'Horário';
  @override String get event_location_label => 'Local';
  @override String get event_address_label => 'Endereço Exato';
  @override String get event_organized_by => 'Organizado por';
  
  @override String get event_about_title => 'Sobre';
  @override String get event_no_description => 'Nenhuma descrição disponível para este evento.';
  @override String get event_tickets_title => 'Ingressos e Reservas';
  
  @override String get event_sold_out_short => 'ESGOTADO';
  @override String event_remaining_seats(String count) => '$count vagas restantes';
  @override String get event_queue_btn => 'LISTA DE ESPERA';
  @override String get event_book_btn => 'RESERVAR';
  
  @override String get event_standard_entry => 'Entrada Padrão';
  @override String get event_all_sold => 'Todos os assentos estão vendidos';
  @override String get event_limited_seats => 'Vagas limitadas';
  @override String get event_book_now_btn => 'RESERVAR AGORA';
  
  @override String event_numbered_seats(String count) => '$count lugares numerados';
  @override String get event_choose_seats_btn => 'ESCOLHER MEUS LUGARES';
  @override String get event_from_price => 'A partir de';

  @override String get events_my_tickets => 'Meus Ingressos';
  @override String get events_buy_ticket => 'Comprar um Ingresso';
  @override String get events_ticket_price => 'Preço do Ingresso';
  @override String get events_date => 'Data';
  @override String get events_time => 'Horário';
  @override String get events_venue => 'Local';
  @override String get events_organizer => 'Organizador';
  @override String get events_attendees => 'Participantes';
  @override String get events_seats_available => 'Vagas Disponíveis';
  @override String get events_sold_out => 'Esgotado';
  @override String get events_book_now => 'Reservar Agora';
  @override String get events_ticket_type => 'Tipo de Ingresso';
  @override String get ticket_standard => 'Padrão';
  @override String get ticket_vip => 'VIP';
  @override String get ticket_gold => 'Ouro';
  @override String get ticket_family => 'Família';
  @override String get ticket_secure_ticket => 'Ingresso Seguro';
  @override String get ticket_not_found => 'Ingresso não encontrado';
  @override String get ticket_location => 'Local';
  @override String get ticket_pin_label => 'Código PIN';
  @override String get ticket_show_qr => 'Mostrar QR';
  @override String get ticket_booking_id => 'ID da Reserva';
  @override String get ticket_add_wallet => 'Carteira';
  @override String get ticket_wallet_coming_soon => 'Integração com a carteira em breve';
  @override String get ticket_share => 'Compartilhar';
  @override String get ticket_share_text => 'Meu Ingresso THIX';
  @override String get ticket_scan_info => 'Apresente este código QR na entrada';
  @override String get ticket_security_title => 'Segurança';
  @override String get ticket_enter_pin => 'Digite seu PIN';
  @override String get ticket_pin_hint => 'Código de 4 dígitos';
  @override String get ticket_pin_incorrect => 'PIN incorreto';
  @override String get ticket_pin_too_many_attempts => 'Muitas tentativas';
  @override String get ticket_attempts_remaining => 'Tentativas restantes';
  @override String get tickets_ticket => 'Ingresso';
  @override String get tickets_completed => 'Concluídos';
  @override String get tickets_no_tickets => 'Nenhum ingresso';
  @override String get tickets_no_tickets_desc => 'Suas reservas aparecerão aqui';
  @override String get tickets_discover => 'Descobrir';
  @override String get tickets_load_error => 'Falha ao carregar seus ingressos';
  @override String tickets_quantity(int count) => count == 0 ? 'Nenhum ingresso' : (count == 1 ? '1 ingresso' : '$count ingressos');

  // ============================================================================
  // RÉSERVATIONS (RESERVATIONS)
  // ============================================================================
  @override String get reservation_title => 'Reservas';
  @override String get reservation_hotel => 'Hotel';
  @override String get reservation_restaurant => 'Restaurante';
  @override String get reservation_transport => 'Transporte';
  @override String get reservation_check_in => 'Check-in';
  @override String get reservation_check_out => 'Check-out';
  @override String get reservation_guests => 'Hóspedes';
  @override String get reservation_rooms => 'Quartos';
  @override String get reservation_book => 'Reservar';
  @override String get reservation_cancel => 'Cancelar';
  @override String get reservation_modify => 'Modificar';
  @override String get reservation_confirm => 'Confirmar Reserva';
  @override String get reservation_my_bookings => 'Minhas Reservas';

  // ============================================================================
  // SANTÉ (HEALTH)
  // ============================================================================
  @override String get health_title => 'THIX Saúde';
  @override String get health_appointments => 'Consultas';
  @override String get health_doctors => 'Médicos';
  @override String get health_hospitals => 'Hospitais';
  @override String get health_pharmacies => 'Farmácias';
  @override String get health_emergency => 'Emergência';
  @override String get health_medical_records => 'Prontuários Médicos';
  @override String get health_prescriptions => 'Receitas Médicas';
  @override String get health_book_appointment => 'Agendar Consulta';
  @override String get health_appointment_date => 'Data da Consulta';
  @override String get health_specialty => 'Especialidade';
  @override String get health_consultation => 'Consulta';
  @override String get health_telemedicine => 'Telemedicina';
  @override String get health_insurance => 'Plano de Saúde';
  @override String get health_symptoms => 'Sintomas';
  @override String get health_find_doctor => 'Encontrar um Médico';

  // ============================================================================
  // MÉDIA & INFOS (MEDIA & INFO)
  // ============================================================================
  @override String get media_title => 'THIX Mídia';
  @override String get media_news => 'Notícias';
  @override String get media_videos => 'Vídeos';
  @override String get media_podcasts => 'Podcasts';
  @override String get media_articles => 'Artigos';
  @override String get media_live => 'Ao vivo';
  @override String get media_categories => 'Categorias';
  @override String get media_bookmarks => 'Favoritos';
  @override String get media_share_article => 'Compartilhar Artigo';
  @override String get media_read_more => 'Ler Mais';
  @override String get media_published_on => 'Publicado em';
  @override String get media_author => 'Autor';
  @override String get info_title => 'Notícias';
  @override String get info_local => 'Local';
  @override String get info_national => 'Nacional';
  @override String get info_international => 'Internacional';
  @override String get info_sports => 'Esportes';
  @override String get info_culture => 'Cultura';
  @override String get info_economy => 'Economia';
  @override String get info_politics => 'Política';
  @override String get info_technology => 'Tecnologia';
  @override String get info_read_full => 'Ler Artigo Completo';

  // ============================================================================
  // MON PAYS (MY COUNTRY)
  // ============================================================================
  @override String get mon_pays_title => 'Meu País';
  @override String get mon_pays_regions => 'Regiões';
  @override String get mon_pays_cities => 'Cidades';
  @override String get mon_pays_culture => 'Cultura';
  @override String get mon_pays_history => 'História';
  @override String get mon_pays_tourism => 'Turismo';
  @override String get mon_pays_discover => 'Descobrir';
  @override String get mon_pays_landmarks => 'Pontos Turísticos';
  @override String get mon_pays_traditions => 'Tradições';

  // ============================================================================
  // COFFRE-FORT (VAULT)
  // ============================================================================
  @override String get vault_title => 'Cofre';
  @override String get vault_documents => 'Documentos';
  @override String get vault_photos => 'Fotos';
  @override String get vault_videos => 'Vídeos';
  @override String get vault_notes => 'Notas';
  @override String get vault_passwords => 'Senhas';
  @override String get vault_add_document => 'Adicionar Documento';
  @override String get vault_upload => 'Enviar';
  @override String get vault_encrypted => 'Criptografado';
  @override String get vault_backup => 'Backup';
  @override String get vault_restore => 'Restaurar';
  @override String get vault_share_secure => 'Compartilhamento Seguro';
  @override String get vault_unlock => 'Desbloquear';
  @override String get vault_lock => 'Bloquear';

  // ============================================================================
  // PAIEMENT (PAYMENT)
  // ============================================================================
  @override String get payment_title => 'Pagamento';
  @override String get payment_method => 'Método de Pagamento';
  @override String get payment_card => 'Cartão de Crédito';
  @override String get payment_mobile_money => 'Mobile Money';
  @override String get payment_bank_transfer => 'Transferência Bancária';
  @override String get payment_cash => 'Dinheiro';
  @override String get payment_confirm => 'Confirmar Pagamento';
  @override String get payment_success => 'Pagamento Concluído';
  @override String get payment_failed => 'Falha no Pagamento';
  @override String get payment_processing => 'Processando…';
  @override String get payment_receipt => 'Recibo';
  @override String get payment_invoice => 'Fatura';

  // ============================================================================
  // RECHERCHE (MISSING PERSONS / SEARCH)
  // ============================================================================
  @override String get search_title => 'Pesquisa THIX';
  @override String get search_subtitle => 'Pessoas Desaparecidas e Avisos Oficiais';
  @override String get search_person_missing => 'Pessoa Desaparecida';
  @override String get search_person_wanted => 'Aviso Oficial de Procurado';
  @override String get search_report_missing => 'Relatar Desaparecimento';
  @override String get search_report_found => 'Relatar Encontrado';
  @override String get search_details => 'Detalhes';
  @override String get search_contact_authorities => 'Contatar Autoridades';
  @override String get search_share_alert => 'Compartilhar Alerta';
  @override String get search_last_seen => 'Visto por último em';
  @override String get search_description => 'Descrição';
  @override String get search_age => 'Idade';
  @override String get search_height => 'Altura';
  @override String get search_weight => 'Peso';
  @override String get search_hair_color => 'Cor do Cabelo';
  @override String get search_eye_color => 'Cor dos Olhos';
  @override String get search_distinguishing_marks => 'Marcas Distintivas';
  @override String get search_clothing => 'Roupas';
  @override String get search_circumstances => 'Circunstâncias';
  @override String get search_case_number => 'Número do Caso';
  @override String get search_reported_by => 'Relatado por';
  @override String get search_official_notice => 'Aviso Oficial';
  @override String get search_community_alert => 'Alerta da Comunidade';

  // ============================================================================
  // À PROXIMITÉ & ALERTES (NEARBY ALERTS)
  // ============================================================================
  @override String get nearby_alerts_title => 'Alertas Próximos';
  @override String get nearby_view_on_map => 'Ver no Mapa';
  @override String get nearby_map_coming_soon => 'Mapa em tela cheia em breve';
  @override String get nearby_map_disabled => 'Mapa desativado (aguardando chave da API)';
  @override String get nearby_active_alerts => 'Alertas Ativos';
  @override String get nearby_missing => 'Desaparecido(a)';
  @override String get nearby_official => 'Oficial';
  @override String get nearby_legend_missing => 'Pessoa Desaparecida';
  @override String get nearby_legend_official => 'Aviso Oficial';
  @override String get nearby_legend_report => 'Relato';
  @override String get nearby_location_required => 'Ativar Serviços de Localização';
  @override String get nearby_location_subtitle => 'Veja os alertas ao seu redor';

  // ============================================================================
  // ADMINISTRATION
  // ============================================================================
  @override String get admin_title => 'Administração THIX';
  @override String get admin_dev_open => 'Desenvolvimento Aberto';
  @override String get admin_actions_section => 'Ações';
  
  @override String get admin_events_title => 'Eventos';
  @override String get admin_events_create => 'Criar';
  @override String get admin_events_search_hint => 'Pesquisar por título...';
  @override String get admin_events_filter => 'Filtro de categoria';
  @override String get admin_events_empty => 'Nenhum evento encontrado';
  @override String get admin_events_no_permission => 'Você não tem permissão para realizar esta ação';
  @override String get admin_events_delete_title => 'Excluir?';
  @override String admin_events_delete_desc(String title) => 'Deseja excluir $title? Esta ação é irreversível.';

  @override String get admin_limits_purchase_rules => 'Regras de Compra';
  @override String get admin_limits_max_person => 'Máx / pessoa (global)';
  @override String get admin_limits_max_transaction => 'Máx / transação (carrinho)';
  @override String get admin_limits_require_thix_id => 'Verificação do THIX ID Obrigatória';
  @override String get admin_limits_require_thix_id_desc => 'Recomendado para eventos de alta demanda.';
  @override String get admin_limits_info_title => 'Arquitetura Segura';
  @override String get admin_limits_info_desc => 'Esses limites são aplicados e verificados diretamente pelas Edge Functions em SQL em tempo real para evitar fraudes e condições de corrida.';

  @override String get admin_stat_events => 'Eventos';
  @override String get admin_stat_bookings => 'Reservas';
  @override String get admin_stat_revenue => 'Receitas';
  @override String get admin_stat_queue => 'Fila';
  @override String get admin_action_events => 'Eventos';
  @override String get admin_action_events_sub => '20 / página';
  @override String get admin_action_create => 'Criar';
  @override String get admin_action_create_sub => 'Upload + Verificar';
  @override String get admin_action_seats => 'Assentos';
  @override String get admin_action_seats_sub => 'Lote de 200';
  @override String get admin_action_reservations => 'Reservas';
  @override String get admin_action_reservations_sub => '50 / página + Filtros';
  @override String get admin_action_limits => 'Antifraude';
  @override String get admin_action_limits_sub => 'Limites';
  @override String get admin_action_analytics => 'Análises';
  @override String get admin_action_analytics_sub => 'RPC';
  @override String get admin_read_only => 'Somente Leitura';
  @override String get admin_bookings_title => 'Reservas • 50/página';
  @override String get admin_bookings_export => 'Exportação de servidor em andamento (tarefa)';
  @override String get admin_bookings_details => 'Detalhes do Ingresso';
  @override String get admin_bookings_event => 'Evento';
  @override String get admin_bookings_unknown_event => 'Evento desconhecido';
  @override String get admin_bookings_id => 'ID da Reserva';
  @override String get admin_bookings_quantity => 'Quantidade';
  @override String get admin_bookings_category => 'Categoria';
  @override String get admin_bookings_amount => 'Valor';
  @override String get admin_bookings_pin => 'PIN';
  @override String get admin_bookings_purchase_date => 'Data de Compra';
  @override String get admin_bookings_close => 'Fechar';
  @override String get admin_bookings_empty => 'Nenhuma reserva encontrada';
  @override String get admin_bookings_unknown_date => 'Data desconhecida';
  @override String admin_bookings_places(int count) => '$count vagas';
  @override String get admin_bookings_status_valid => 'Válido';
  @override String get admin_bookings_status_used => 'Usado';
  @override String get admin_bookings_status_cancelled => 'Cancelado';
  @override String get admin_bookings_status_postponed => 'Adiado';
  @override String get admin_bookings_status_pending => 'Pendente';
  @override String admin_queue_title(int count) => 'Fila de Espera • Tempo Real ($count)';
  @override String get admin_queue_realtime_desc => 'Tempo real ativo • Atualiza automaticamente quando usuários entram';
  @override String get admin_queue_empty => 'A fila está vazia';
  @override String get admin_queue_event_fallback => 'Evento';
  @override String admin_queue_item_meta(String userId, int qty, String status) => 'Usuário: $userId • $qty vagas • $status';
  @override String get admin_queue_notify => 'Notificar';
  @override String get admin_queue_notified => 'Usuário notificado (expira em 10 minutos)';
  @override String get admin_queue_position => 'Posição';
  @override String get admin_queue_places => 'Vagas';
  @override String get admin_analytics_title => 'Análises • Desempenho';
  @override String get admin_analytics_fill_rate => 'Taxa de Ocupação';
  @override String get admin_analytics_avg_cart => 'Carrinho Médio';
  @override String get admin_analytics_no_show => 'Não Comparecimento';
  @override String get admin_analytics_rev_per_event => 'Receita / evento';
  @override String get admin_analytics_revenue_7d => 'Receita (7 dias)';
  @override String get admin_analytics_no_data => 'Nenhum dado disponível';
  @override String get admin_analytics_error => 'Falha ao carregar as estatísticas';
  @override String get admin_event_create => 'Criar Evento';
  @override String get admin_event_edit => 'Editar Evento';
  @override String get admin_event_btn_create => 'Criar';
  @override String get admin_event_btn_save => 'Salvar';
  @override String get admin_event_cover => 'Capa';
  @override String get admin_event_banner => 'Banner';
  @override String get admin_event_title => 'Título *';
  @override String get admin_event_desc => 'Descrição *';
  @override String get admin_event_category => 'Categoria';
  @override String get admin_event_subcategory => 'Subcategoria';
  @override String get admin_event_datetime => 'Data e Hora';
  @override String get admin_event_start => 'Início';
  @override String get admin_event_end => 'Fim (opcional)';
  @override String get admin_event_add_end => 'Adicionar Hora de Término';
  @override String get admin_event_city => 'Cidade *';
  @override String get admin_event_location => 'Local *';
  @override String get admin_event_address => 'Endereço';
  @override String get admin_event_organizer => 'Organizador';
  @override String get admin_event_phone => 'Telefone';
  @override String get admin_event_email => 'E-mail de Contato';
  @override String get admin_event_tiers_title => 'Categorias e Capacidade';
  @override String get admin_event_add_tier_btn => 'Adicionar VVIP, VIP…';
  @override String get admin_event_status => 'Status';
  @override String get admin_event_visibility => 'Visibilidade';
  @override String get admin_event_cat_concert => 'Show';
  @override String get admin_event_cat_conference => 'Conferência';
  @override String get admin_event_cat_sport => 'Esporte';
  @override String get admin_event_cat_festival => 'Festival';
  @override String get admin_event_cat_theatre => 'Teatro';
  @override String get admin_event_cat_other => 'Outro';
  @override String get admin_event_status_upcoming => 'Próximo';
  @override String get admin_event_status_ongoing => 'Em andamento';
  @override String get admin_event_status_completed => 'Concluído';
  @override String get admin_event_status_cancelled => 'Cancelado';
  @override String get admin_event_vis_default => 'Próximo (padrão)';
  @override String get admin_event_vis_recommended => 'Recomendado';
  @override String get admin_event_vis_featured => 'Em destaque';
  @override String get admin_event_dialog_add_tier => 'Adicionar categoria';
  @override String get admin_event_dialog_name => 'Nome (ex: VVIP)';
  @override String admin_event_dialog_price(String currency) => 'Preço ($currency)';
  @override String get admin_event_dialog_capacity => 'Capacidade';
  @override String get admin_event_dialog_cancel => 'Cancelar';
  @override String get admin_event_dialog_add => 'Adicionar';
  @override String get admin_event_err_readonly => 'Somente Leitura';
  @override String get admin_event_err_min_tier => 'Pelo menos uma categoria é obrigatória';
  @override String get admin_event_success => 'Evento salvo com sucesso';
  @override String get admin_event_err_title_req => 'O título é obrigatório';
  @override String get admin_event_err_desc_min => 'Mínimo de 10 caracteres';
  @override String get admin_event_err_city_req => 'A cidade é obrigatória';
  @override String get admin_event_err_loc_req => 'O local é obrigatório';
  @override String get admin_seat_page_title => 'Mapa de Assentos e Preços';
  @override String get admin_seat_target_event => 'Evento Alvo';
  @override String get admin_seat_select_event => 'Selecione um evento';
  @override String admin_seat_max_limit(int count) => 'Máximo de $count assentos';
  @override String admin_seat_generated(int count) => '$count assentos gerados';
  @override String get admin_seat_load_error => 'Falha ao carregar os assentos';
  @override String get admin_seat_pricing_title => 'Precificação Dinâmica';
  @override String get admin_seat_layout_title => 'Formato e Layout';
  @override String get admin_seat_rows => 'Fileiras';
  @override String get admin_seat_per_row => 'Assentos / fileira';
  @override String get admin_seat_center_aisle => 'Corredor Central';
  @override String get admin_seat_aisle_desc => 'Espaço vazio no meio';
  @override String get admin_seat_cats_per_row => 'Categorias por fileira';
  @override String get admin_seat_generating => 'Gerando…';
  @override String admin_seat_generate_btn(int count) => 'Gerar $count assentos';
  @override String get admin_seat_preview => 'Pré-visualização do layout atual';
  @override String get admin_seat_no_seats => 'Nenhum assento gerado';
  @override String get admin_seat_cat_standard => 'Padrão';
  @override String get admin_seat_cat_vip => 'VIP';
  @override String get admin_seat_cat_gold => 'Ouro';
  @override String get admin_seat_cat_family => 'Família';
  @override String get admin_seat_legend_reserved => 'Reservado';
  @override String get admin_seat_legend_sold => 'Vendido';
  @override String get seat_map_stage => 'Palco';

  // ============================================================================
  // ERREURS & VALIDATION (ERRORS & VALIDATION)
  // ============================================================================
  @override String get error_generic => 'Ocorreu um erro';
  @override String get error_validation => 'Dados inválidos';
  @override String get error_file_too_large => 'O arquivo é muito grande';
  @override String get error_unsupported_format => 'Formato não suportado';
  @override String get error_permission_denied => 'Permissão negada';
  @override String get error_camera_unavailable => 'Câmera indisponível';
  @override String get error_microphone_unavailable => 'Microfone indisponível';
  @override String get error_location_unavailable => 'Serviços de localização indisponíveis';
  @override String get error_network => 'Erro de rede';
  @override String get error_timeout => 'A solicitação expirou';
  @override String get error_server => 'Erro no servidor';
  @override String get error_not_found => 'Não encontrado';

  // ============================================================================
  // TEMPS & DATES RELATIVES (RELATIVE DATES & TIMES)
  // ============================================================================
  @override String get common_just_now => 'Agora mesmo';
  @override String get common_in_the_future => 'Mais tarde';
  @override String common_minutes_ago(int count) => count == 1 ? 'Há 1 minuto' : 'Há $count minutos';
  @override String common_hours_ago(int count) => count == 1 ? 'Há 1 hora' : 'Há $count horas';
  @override String common_days_ago(int count) => count == 1 ? 'Há 1 dia' : 'Há $count dias';
  @override String common_seconds_ago(int count) => count == 1 ? 'Há 1 segundo' : 'Há $count segundos';
  @override String common_weeks_ago(int count) => count == 1 ? 'Há 1 semana' : 'Há $count semanas';
  @override String common_months_ago(int count) => count == 1 ? 'Há 1 mês' : 'Há $count meses';
  @override String common_years_ago(int count) => count == 1 ? 'Há 1 ano' : 'Há $count anos';
  @override String common_in_minutes(int count) => count == 1 ? 'Em 1 minuto' : 'Em $count minutos';
  @override String common_in_hours(int count) => count == 1 ? 'Em 1 hora' : 'Em $count horas';
  @override String common_in_days(int count) => count == 1 ? 'Em 1 dia' : 'Em $count dias';

  // ============================================================================
  // THIX MEDIA & IA SOURCES
  // ============================================================================
  @override String get live_send => 'Enviar';
  @override String get live_ending => 'Encerrando ao vivo...';
  @override String get live_network_quality => 'Qualidade da rede';
  @override String get source_type_official => 'Oficial';
  @override String get source_type_world_bank => 'Banco Mundial';
  @override String get source_type_government => 'Governo';
  @override String get source_type_default => 'Fonte Verificada';
  @override String get source_aria_label => 'Fonte de informação';
    // ============================================================================
  // THIX MEDIA & IA SOURCES
  // ============================================================================
  @override String get live_go_live => 'Iniciar Transmissão';
  @override String get live_title => 'Título da Transmissão';
  @override String get live_start => 'Começar';
  @override String get live_end => 'Encerrar';
  @override String get live_duration => 'Duração';
  @override String get live_peak_viewers => 'Pico de Espectadores';
  @override String get live_chat_disabled => 'O chat está desativado.';
  @override String get live_share => 'Compartilhar';
  @override String get live_report => 'Denunciar';
  @override String get live_follow_host => 'Seguir';
  @override String get live_gift_send => 'Enviar Presente';
  @override String get live_quality_auto => 'Automático';
  @override String get live_quality_hd => 'HD';
  @override String get live_quality_sd => 'SD';
  @override String get live_quality_low => 'Baixa';

  @override String get insight_source_unverified => 'Fonte não verificada';
  @override String get insight_recommended_actions => 'Ações recomendadas';
  @override String get insight_key_findings => 'Principais descobertas';
  @override String get insight_summary => 'Resumo';
  @override String get insight_full_analysis => 'Análise Completa';
  @override String get insight_generated_by => 'Gerado por IA';
  @override String get insight_disclaimer => 'Esta é uma análise gerada por IA. Por favor, verifique as informações.';

  @override String get risk_level_label => 'Nível de Risco';
  @override String get risk_mitigation => 'Mitigação';
  @override String get risk_impact => 'Impacto';
  @override String get risk_probability => 'Probabilidade';
  @override String get risk_assessment => 'Avaliação de Risco';

  @override String get live_leave_btn => 'Sair da Live';
  @override String get live_chat_empty => 'Nenhuma mensagem ainda.';
  @override String get live_chat_hint => 'Diga algo...';
  @override String get live_like => 'Curtir';
  @override String get live_send => 'Enviar';
  @override String get live_viewers => 'espectadores';
  @override String get live_likes => 'curtidas';
  @override String get live_leaving => 'Saindo...';
  @override String get live_network_quality => 'Qualidade da rede';
  
  @override String get insight_type_market => 'Mercado';
  @override String get insight_type_finance => 'Finanças';
  @override String get insight_type_strategy => 'Estratégia';
  @override String get insight_type_business => 'Negócios';
  @override String get insight_type_insight => 'Insight';
  @override String get insight_confidence_label => 'Nível de confiança';
  @override String get insight_source_verified => 'Fonte verificada';
  
  @override String get risk_critical => 'Crítico';
  @override String get risk_high => 'Alto';
  @override String get risk_medium => 'Médio';
  @override String get risk_low => 'Baixo';
  
  @override String get source_type_official => 'Oficial';
  @override String get source_type_world_bank => 'Banco Mundial';
  @override String get source_type_government => 'Governo';
  @override String get source_type_default => 'Fonte Verificada';
  @override String get source_aria_label => 'Fonte de informação';

}
