# Eternus FC – site estático + Supabase
1. Crie um projeto em supabase.com e rode `sql/setup.sql` no SQL Editor.
2. Authentication > Users > Add user: crie o e-mail/senha do admin. Em Authentication > Providers > Email, desative "Allow new users to sign up".
3. Edite `assets/config.js` com a Project URL e a chave anon (Project Settings > API).
4. Publique a pasta em Netlify, Vercel, GitHub Pages ou Cloudflare Pages.
Se já rodou o SQL antes, rode o novo `sql/setup.sql` de novo: ele só acrescenta idade, altura, pé dominante e o bucket de fotos a tabela de configurações (logo) e as tabelas do financeiro.
Páginas: index, elenco, contato (público) · admin/index (login), admin/elenco, admin/contato, admin/configuracoes (logo), admin/mensalidades (controle de mensalidades, gera a entrada no financeiro), admin/financeiro e admin/desejos (controle financeiro e lista de desejos, só admin).
