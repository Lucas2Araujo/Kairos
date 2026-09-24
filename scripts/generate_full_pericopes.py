import sqlite3
from pathlib import Path

# Portuguese book titles and chapter themes for generating comprehensive section headings across all 66 books
BOOK_THEMES: dict[int, dict[int, str]] = {
    # 1: Gênesis
    1: {
        1: "A Criação dos Céus e da Terra", 2: "O Jardim do Éden e a Criação do Homem",
        3: "A Queda do Homem e a Promessa da Redenção", 4: "Caim e Abel",
        6: "A Corrupção da Humanidade e a Arca de Noé", 7: "O Dilúvio Universal",
        9: "A Aliança de Deus com Noé", 11: "A Torre de Babel",
        12: "O Chamado de Abrão", 15: "A Aliança da Fé com Abrão",
        18: "A Promessa de Isaque e a Intercessão por Sodoma", 19: "A Destruição de Sodoma e Gomorra",
        22: "O Sacrifício de Isaque no Monte Moriá", 24: "Isaque e Rebeca",
        28: "O Sonho de Jacó em Betel", 32: "Jacó Luta com o Anjo em Peniel",
        37: "José e seus Sonhos Vendido ao Egito", 39: "José na Casa de Potifar",
        41: "José Interpreta os Sonhos de Faraó e Governa o Egito", 45: "José se Revela aos seus Irmãos",
        50: "A Morte de Jacó e a Esperança de José"
    },
    # 2: Êxodo
    2: {
        1: "A Opressão dos Israelitas no Egito", 2: "O Nascimento e Preparo de Moisés",
        3: "Moisés Diante da Sarça Ardente", 7: "As Pragas sobre a Terra do Egito",
        12: "A Instituição da Páscoa e a Saída do Egito", 14: "A Travessia Triunfal do Mar Vermelho",
        16: "O Maná do Céu no Deserto", 19: "Israel Acampado ao Pé do Monte Sinai",
        20: "A Promulgação dos Dez Mandamentos", 24: "A Selagem da Antiga Aliança",
        25: "As Instruções para a Construção do Santuário", 32: "A Idolatria do Bezerro de Ouro",
        34: "A Renovação das Tábuas e a Glória no Rosto de Moisés", 40: "A Inauguração do Tabernáculo"
    },
    # 3: Levítico
    3: {
        1: "As Leis sobre os Holocaustos", 11: "As Leis de Saúde e Distinção dos Animais",
        16: "O Dia da Expiação (Yom Kippur)", 19: "Exortações à Santidade Prática",
        23: "O Calendário das Festas Solenes do Senhor", 25: "O Ano do Jubileu e da Redenção",
        26: "Bênçãos da Obediência e Advertências"
    },
    # 4: Números
    4: {
        1: "O Primeiro Censo no Deserto de Sinai", 6: "O Voto de Nazireu e a Bênção Sacerdotal",
        9: "A Nuvem Guiando o Povo no Deserto", 13: "O Envio dos Doze Espias a Canaã",
        14: "A Rebeldia do Povo e os Quarenta Anos de Peregrinação", 21: "A Serpente de Bronze",
        22: "Balaão e sua Jumenta no Caminho", 24: "As Profecias da Estrela de Jacó"
    },
    # 5: Deuteronômio
    5: {
        1: "A Recordação da Jornada pelo Deserto", 4: "Exortação à Fidelidade aos Mandamentos",
        5: "A Repetição dos Dez Mandamentos", 6: "O Shemá: Amar a Deus de Todo o Coração",
        8: "O Cuidado de Não Esquecer do Senhor na Prosperidade", 28: "As Bênçãos no Monte Gerizim e as Maldições no Monte Ebal",
        30: "A Escolha entre a Vida e a Morte", 34: "A Morte de Moisés no Monte Nebo"
    },
    # 6: Josué
    6: {
        1: "O Chamado de Josué: Sê Forte e Corajoso", 2: "Raabe e os Espias em Jericó",
        3: "A Travessia do Rio Jordão", 6: "A Queda das Muralhas de Jericó",
        10: "O Sol se Detém sobre Gibeão", 24: "O Pacto em Siquém: Eu e a Minha Casa Serviremos ao Senhor"
    },
    # 7: Juízes
    7: {
        2: "O Ciclo de Desobediência e Libertação", 4: "O Cântico de Vitória de Débora e Baraque",
        6: "O Chamado de Gideão e a Prova da Lã", 7: "A Vitória dos Trezentos de Gideão",
        11: "Jefté e a sua Libertação", 13: "O Nascimento de Sansão",
        16: "Sansão, Dalila e a Queda em Gaza"
    },
    # 8: Rute
    8: {
        1: "A Decisão de Rute ao Lado de Noemi", 2: "Rute nos Campos de Boaz",
        3: "O Pedido de Redenção na Eira", 4: "Boaz Resgata Rute e a Genealogia de Davi"
    },
    # 9: 1 Samuel
    9: {
        1: "A Oração de Ana e o Nascimento de Samuel", 3: "A Vocação Profética do Jovem Samuel",
        8: "O Povo Pede um Rei para Israel", 16: "Davi Ungido por Samuel em Belém",
        17: "Davi e o Gigante Golias no Vale de Elá", 18: "A Amizade Exemplar de Davi e Jônatas",
        24: "Davi Poupa a Vida de Saul na Caverna de En-Gedi"
    },
    # 10: 2 Samuel
    10: {
        1: "O Lamento de Davi por Saul e Jônatas", 5: "Davi Ungido Rei sobre Todo o Israel e a Conquista de Jerusalém",
        6: "A Arca da Aliança Conduzida com Alegria a Jerusalém", 7: "A Promessa Eterna da Casa de Davi",
        11: "O Pecado de Davi com Bate-Seba", 12: "A Denúncia do Profeta Natã e o Arrependimento de Davi",
        24: "O Censo de Davi e o Altar na Eira de Araúna"
    },
    # 11: 1 Reis
    11: {
        3: "A Sabedoria Concedida a Salomão", 6: "A Edificação do Templo do Senhor em Jerusalém",
        8: "A Solene Dedicação do Templo", 10: "A Visita da Rainha de Sabá",
        12: "A Divisão do Reino entre Roboão e Jeroboão", 17: "Elias Sustentado junto ao Ribeiro de Querite",
        18: "O Desafio do Monte Carmelo contra os Profetas de Baal", 19: "A Voz Mansa e Delicada de Deus no Horebe"
    },
    # 12: 2 Reis
    12: {
        2: "A Ascensão Triunfal de Elias em Redemoinho ao Céu", 4: "Os Milagres de Eliseu e o Azeite da Viúva",
        5: "A Cura da Lepra do Comandante Naamã", 6: "O Exército Celestial de Carros de Fogo",
        17: "A Queda de Samaria e o Cativeiro de Israel", 18: "A Fé Heroica do Rei Ezequias",
        22: "A Descoberta do Livro da Lei no Reinado de Josias", 25: "A Queda de Jerusalém e o Cativeiro Babilônico"
    },
    # 13: 1 Crônicas
    13: {
        4: "A Famosa Oração de Jabez", 16: "O Magnífico Salmo de Gratidão de Davi",
        21: "O Censo e a Aquisição do Monte do Templo", 29: "As Ofertas Voluntárias e a Oração Final de Davi"
    },
    # 14: 2 Crônicas
    14: {
        1: "O Pedido de Sabedoria de Salomão em Gibeão", 7: "A Glória Enche o Templo e a Promessa de Restauração",
        20: "A Oração de Jeosafá e a Batalha Vencida pelo Louvor", 34: "O Reavivamento e as Reformas de Josias"
    },
    # 15: Esdras
    15: {
        1: "O Decreto Libertador de Ciro Rei da Pérsia", 3: "A Reconstrução do Altar e Lançamento dos Alicerces",
        7: "A Vinda de Esdras para Ensinar a Lei em Jerusalém", 9: "A Oração de Confissão de Esdras"
    },
    # 16: Neemias
    16: {
        1: "A Oração e o Pranto de Neemias por Jerusalém", 2: "A Inspeção Noturna das Muralhas em Ruínas",
        4: "A Defesa Armada e a Reconstrução das Muralhas", 8: "A Leitura Pública e Emocionada da Lei",
        9: "O Grande Reavivamento e a Confissão Nacional"
    },
    # 17: Ester
    17: {
        2: "Ester Escolhida como Rainha da Pérsia", 3: "A Conspiração Destrutiva de Hamã",
        4: "A Decisão de Ester: Se Perecer, Pereci", 7: "A Revelação no Banquete e a Queda de Hamã",
        9: "A Instituição Festiva dos Dias de Purim"
    },
    # 18: Jó
    18: {
        1: "A Integridade de Jó e a Grande Prova", 2: "A Paciência de Jó Diante do Sofrimento",
        19: "A Declaração Imorredoura: Eu Sei que o Meu Redentor Vive", 38: "O Senhor Responde a Jó no Meio do Redemoinho",
        42: "A Restauração em Dobro e a Bênção Final de Jó"
    },
    # 19: Salmos
    19: {
        1: "O Homem Bem-Aventurado e a Árvore Frutífera", 8: "A Glória Excelsa de Deus na Criação",
        19: "Os Céus Proclamam a Glória de Deus e a Lei Perfeita", 23: "O Senhor é o Meu Pastor, Nada Me Faltará",
        24: "O Rei da Glória Entra pelas Portas Eternas", 34: "O Louvor Contínuo e o Anjo que Acampa ao Redor",
        46: "Deus é o Nosso Refúgio e Fortaleza", 51: "A Súplica Penitencial por um Coração Puro",
        91: "O Abrigo Inabalável do Onipotente", 100: "Celebrai com Júbilo ao Senhor, Todas as Terras",
        103: "Bendize, ó Minha Alma, ao Senhor e Lembra-te de seus Benefícios", 119: "Lâmpada para os Meus Pés é a Tua Palavra",
        121: "Elevo os Meus Olhos para os Montes: De Onde Me Virá o Socorro?", 139: "Senhor, Tu Me Sondas e Me Conheces",
        150: "Tudo o que Tem Fôlego Louve ao Senhor"
    },
    # 20: Provérbios
    20: {
        1: "O Princípio do Saber é o Temor do Senhor", 3: "Confia no Senhor de Todo o Teu Coração",
        4: "Adquire a Sabedoria Acima de Tudo", 6: "Lições da Formiga e Advertências contra a Preguiça",
        8: "O Chamado Sublime e Eterno da Sabedoria", 31: "O Elogio Nobre da Mulher Virtuosa"
    },
    # 21: Eclesiastes
    21: {
        1: "Tudo é Vaidade Debaixo do Sol", 3: "Tudo Tem o Seu Tempo Determinado por Deus",
        12: "Lembra-te do Teu Criador nos Dias da Tua Mocidade"
    },
    # 22: Cânticos
    22: {
        2: "A Voz do Meu Amado: O Inverno Já Passou", 8: "O Amor é Forte como a Morte"
    },
    # 23: Isaías
    23: {
        6: "A Visão da Glória de Deus no Templo e o Envio do Profeta", 7: "A Profecia da Virgem e o Nome Emanuel",
        9: "O Nascimento do Menino e o Príncipe da Paz", 11: "O Renovo do Tronco de Jessé",
        40: "Consolai, Consolai o Meu Povo: A Voz que Clama no Deserto", 53: "O Servo Sofredor Ferido pelas Nossas Transgressões",
        55: "O Convite Gratuito às Águas Vivas da Graça", 65: "A Promessa Gloriosa de Novos Céus e Nova Terra"
    },
    # 24: Jeremias
    24: {
        1: "A Vocação do Jovem Profeta Jeremias", 29: "A Carta aos Cativos e os Pensamentos de Paz",
        31: "A Profecia Magna da Nova Aliança Escrita no Coração", 33: "Clama a Mim e Responder-te-ei Coisas Grandes"
    },
    # 25: Lamentações
    25: {
        3: "As Misericórdias do Senhor São a Causa de Não Sermos Consumidos"
    },
    # 26: Ezequiel
    26: {
        1: "A Visão dos Quatro Seres Viventes e o Trono Celestial", 34: "A Profecia contra os Maus Pastores e a Vinda do Bom Pastor",
        36: "A Promessa de um Coração de Carne e um Novo Espírito", 37: "A Visão dos Ossos Secos que Revivem",
        47: "O Rio de Águas Vivas que Flui do Templo"
    },
    # 27: Daniel
    27: {
        1: "Os Quatro Jovens Hebreus Fieis na Babilônia", 2: "O Sonho de Nabucodonosor e a Grande Estátua dos Impérios",
        3: "A Fornalha Ardente e a Presença do Quarto Homem", 6: "Daniel na Cova dos Leões",
        7: "A Visão dos Quatro Animais e o Ancião de Dias", 8: "A Visão do Carneiro, do Bode e as Duas Mil e Trezentas Tardes e Manhãs",
        12: "O Tempo do Fim e o Brilho dos Sábios como as Estrelas"
    },
    # 28: Oséias
    28: {
        6: "Vinde e Voltemos ao Senhor: Conheçamos e Prossigamos em Conhecer o Senhor",
        11: "O Amor Paterno e Inabalável de Deus por Israel"
    },
    # 29: Joel
    29: {
        2: "O Derramamento do Espírito Santo sobre Toda a Carne"
    },
    # 30: Amós
    30: {
        5: "Buscai ao Senhor e Vivei: Corra a Justiça como um Rio"
    },
    # 31: Obadias
    31: {
        1: "O Julgamento de Edom e o Triunfo do Monte Sião"
    },
    # 32: Jonas
    32: {
        1: "A Fuga de Jonas e a Tempestade no Mar", 2: "A Oração de Jonas no Ventre do Grande Peixe",
        3: "O Arrependimento de Nínive em Pano de Saco", 4: "A Planta da Aboboreira e a Compaixão Divina"
    },
    # 33: Miquéias
    33: {
        5: "A Profecia do Governador Nascido em Belém de Judá", 6: "O que o Senhor Pede: Praticar a Justiça, Amar a Misericórdia e Andar Humildemente"
    },
    # 34: Naum
    34: {
        1: "A Majestade de Deus e Boas Novas de Paz"
    },
    # 35: Habacuque
    35: {
        2: "O Justo Viverá pela sua Fé", 3: "A Oração e o Cântico de Louvor de Habacuque"
    },
    # 36: Sofonias
    36: {
        3: "O Cântico de Alegria e a Restauração de Sião"
    },
    # 37: Ageu
    37: {
        2: "A Glória da Segunda Casa Será Maior do que a da Primeira"
    },
    # 38: Zacarias
    38: {
        4: "Não por Força nem por Poder, mas pelo Meu Espírito", 9: "O Rei Humilde que Entra Montado em um Jumentinho"
    },
    # 39: Malaquias
    39: {
        3: "O Mensageiro da Aliança e a Fidelidade nos Dízimos", 4: "O Sol da Justiça com Cura em suas Asas"
    },
    # 40: Mateus
    40: {
        1: "A Genealogia e o Nascimento de Jesus Cristo", 2: "A Visita dos Magos do Oriente",
        3: "O Ministério de João Batista e o Batismo do Messias", 4: "A Vitória de Jesus sobre a Tentação no Deserto",
        5: "O Sermão do Monte: As Bem-Aventuranças e a Luz do Mundo", 6: "A Oração do Pai Nosso e a Confiança na Providência",
        7: "A Regra Áurea e os Dois Fundamentos", 8: "Milagres de Cura e a Autoridade sobre a Tempestade",
        13: "As Parábolas do Reino dos Céus", 14: "A Multiplicação dos Pães e Jesus Andando sobre as Águas",
        16: "A Confissão de Pedro: Tu és o Cristo", 17: "A Transfiguração no Monte",
        24: "O Sermão Profético dos Sinais dos Tempos", 26: "A Santa Ceia e a Agonia no Getsêmani",
        27: "A Crucificação e Morte do Redentor", 28: "A Ressurreição Gloriosa e a Grande Comissão"
    },
    # 41: Marcos
    41: {
        1: "O Evangelho do Servo Poderoso e o Início do Ministério", 2: "A Cura do Paralítico de Cafarnaum",
        4: "O Semeador e a Tempestade Acalmada", 5: "A Ressurreição da Filha de Jairo",
        8: "O Custo do Discipulado: Tomar a sua Cruz", 11: "A Entrada Triunfal em Jerusalém",
        16: "A Mensagem do Túmulo Vazio e a Ascensão ao Céu"
    },
    # 42: Lucas
    42: {
        1: "O Cântico do Magnificat de Maria", 2: "O Nascimento em Belém e o Cântico dos Anjos",
        4: "A Leitura em Nazaré: O Espírito do Senhor Está sobre Mim", 10: "A Parábola do Bom Samaritano",
        15: "As Parábolas da Moeda, da Ovelha e do Filho Pródigo", 19: "Zaqueu o Publicano Salvo em Jericó",
        24: "Os Discípulos no Caminho de Emaús"
    },
    # 43: João
    43: {
        1: "No Princípio Era o Verbo: A Encarnação da Luz", 2: "O Primeiro Sinal: As Bodas de Caná",
        3: "Nicodemos e o Novo Nascimento: Deus Amou o Mundo", 4: "A Mulher de Samaria e a Água Viva",
        6: "O Pão da Vida que Desceu do Céu", 8: "A Mulher Apanhada em Adultério e a Luz do Mundo",
        10: "O Bom Pastor que Dá a Vida pelas Ovelhas", 11: "Eu Sou a Ressurreição e a Vida: Lázaro Revive",
        14: "Não se Turbe o Vosso Coração: Eu Sou o Caminho, a Verdade e a Vida", 15: "A Videira Verdadeira e os Ramos",
        17: "A Magna Oração Sacerdotal de Jesus pela Unidade", 20: "A Ressurreição e a Fé Inabalável",
        21: "Jesus à Beira do Mar de Tiberíades: Apascenta as Minhas Ovelhas"
    },
    # 44: Atos
    44: {
        1: "A Promessa do Espírito Santo e a Ascensão de Cristo", 2: "O Dia de Pentecostes e o Nascimento da Igreja",
        3: "A Cura do Coxo na Porta Formosa do Templo", 7: "O Testemunho Fiel e Martírio de Estêvão",
        9: "A Conversão de Saulo na Estrada de Damasco", 10: "Pedro e o Centurião Cornélio em Cesareia",
        16: "O Terremoto na Prisão de Filipos e o Carcereiro Salvo", 17: "O Discurso de Paulo no Areópago de Atenas",
        27: "A Tempestade e o Naufrágio na Ilha de Malta", 28: "Paulo Pregando o Reino de Deus em Roma"
    },
    # 45: Romanos
    45: {
        1: "O Evangelho é o Poder de Deus para a Salvação", 3: "A Justificação Gratuita pela Fé em Jesus",
        5: "Paz com Deus por Meio de Nosso Senhor Jesus Cristo", 8: "Nenhuma Condenação Há: Mais que Vencedores",
        12: "O Culto Racional e a Transformação pela Renovação da Mente"
    },
    # 46: 1 Coríntios
    46: {
        1: "A Palavra da Cruz: Sabedoria e Poder de Deus", 3: "Vós Sois Santuário do Espírito Santo",
        11: "A Solene Ceia do Senhor", 13: "O Hino Imorredouro ao Amor Cristão",
        15: "A Vitória Gloriosa sobre a Morte pela Ressurreição"
    },
    # 47: 2 Coríntios
    47: {
        4: "Temos este Tesouro em Vasos de Barro", 5: "Uma Nova Criatura em Cristo e o Ministério da Reconciliação",
        12: "A Minha Graça te Basta: O Poder Aperfeiçoado na Fraqueza"
    },
    # 48: Gálatas
    48: {
        2: "Estou Crucificado com Cristo: Já Não Sou Eu quem Vive", 5: "A Liberdade em Cristo e o Fruto do Espírito"
    },
    # 49: Efésios
    49: {
        1: "As Ricas Bênçãos Espirituais em Cristo", 2: "Pela Graça Sois Salvos, Mediante a Fé",
        6: "A Armadura Completa de Deus para o Combate Espiritual"
    },
    # 50: Filipenses
    50: {
        1: "O Viver é Cristo e o Morrer é Lucro", 2: "O Hino da Humilhação e Exaltação de Cristo",
        4: "Alegrai-vos Sempre no Senhor: Tudo Posso Naquele que Me Fortalece"
    },
    # 51: Colossenses
    51: {
        1: "A Supremacia Absoluta de Cristo sobre Toda a Criação", 3: "Buscai as Coisas Lá do Alto, Onde Cristo Está"
    },
    # 52: 1 Tessalonicenses
    52: {
        4: "A Esperança Gloriosa da Volta do Senhor", 5: "O Dia do Senhor e a Vigilância Cristã"
    },
    # 53: 2 Tessalonicenses
    53: {
        2: "A Advertência contra o Homem da Iniquidade e a Firmeza na Verdade"
    },
    # 54: 1 Timóteo
    54: {
        2: "Um Só Deus e um Só Mediador entre Deus e os Homens", 6: "O Bom Combate da Fé e o Perigo do Amor ao Dinheiro"
    },
    # 55: 2 Timóteo
    55: {
        3: "Toda a Escritura é Inspirada por Deus", 4: "Combati o Bom Combate, Completei a Carreira, Guardei a Fé"
    },
    # 56: Tito
    56: {
        2: "A Graça Salvadora de Deus Manifestada a Todos os Homens"
    },
    # 57: Filemom
    57: {
        1: "O Perdão e o Resgate Fraterno de Onésimo"
    },
    # 58: Hebreus
    58: {
        1: "A Revelação Suprema de Deus no Filho", 4: "O Descanso do Povo de Deus e a Palavra Viva e Eficaz",
        7: "Jesus, Sumo Sacerdote Eterno segundo a Ordem de Melquisedeque", 11: "A Galeria dos Heróis da Fé",
        12: "Olhando Firmemente para Jesus, Autor e Consumador da Fé"
    },
    # 59: Tiago
    59: {
        1: "A Sabedoria nas Provações e a Prática da Palavra", 2: "A Fé Viva Demonstrada pelas Boas Obras"
    },
    # 60: 1 Pedro
    60: {
        1: "A Esperança Viva pela Ressurreição de Jesus", 2: "A Pedra Angular Viva e a Geração Eleita"
    },
    # 61: 2 Pedro
    61: {
        1: "A Vocação Cristã e a Firme Palavra dos Profetas", 3: "A Certeza da Volta do Senhor e os Novos Céus"
    },
    # 62: 1 João
    62: {
        1: "A Comunhão na Luz e a Purificação pelo Sangue de Jesus", 3: "O Amor Incomparável do Pai por Nós",
        4: "Deus é Amor: Aquele que Não Ama Não Conhece a Deus"
    },
    # 63: 2 João
    63: {
        1: "O Andar na Verdade e no Amor Fraterno"
    },
    # 64: 3 João
    64: {
        1: "A Cooperação com a Verdade e a Hospitalidade Cristã"
    },
    # 65: Judas
    65: {
        1: "Batalhar pela Fé Entregue aos Santos e a Doxologia Final"
    },
    # 66: Apocalipse
    66: {
        1: "A Visão Majestosa do Filho do Homem", 2: "As Mensagens às Igrejas de Éfeso, Esmirna, Pérgamo e Tiatira",
        3: "As Mensagens às Igrejas de Sardes, Filadélfia e Laodiceia", 4: "A Visão do Trono Celestial e a Adoração Eterna",
        5: "O Cordeiro que Venceu para Abrir o Livro dos Sete Selos", 7: "A Grande Multidão de Todas as Nações e Línguas",
        11: "O Triunfo Final: O Reino do Mundo Passou a Ser de Nosso Senhor", 12: "A Mulher, o Dragão e a Vitória pelo Sangue do Cordeiro",
        14: "As Três Mensagens Angélicas e o Evangelho Eterno", 19: "As Bodas do Cordeiro e o Cavaleiro do Cavalo Branco",
        20: "O Milênio e a Derrota Final do Mal", 21: "Um Novo Céu e uma Nova Terra: A Nova Jerusalém",
        22: "O Rio da Água da Vida: Eis que Cedo Venho"
    },
}


def build_full_pericopes_data(ara_db_path: str = "assets/modules/ARA.sqlite") -> list[tuple[int, int, int, str]]:
    """Gera lista com títulos de seções cobrindo todos os 66 livros da Bíblia."""
    conn = sqlite3.connect(ara_db_path)
    cur = conn.cursor()

    all_books = cur.execute("SELECT id, name FROM book ORDER BY id;").fetchall()
    results: list[tuple[int, int, int, str]] = []

    for bid, bname in all_books:
        # Pega todos os capítulos existentes deste livro
        chapters = [r[0] for r in cur.execute("SELECT DISTINCT chapter FROM verse WHERE book_id = ? ORDER BY chapter;", (bid,)).fetchall()]
        book_theme_map = BOOK_THEMES.get(bid, {})

        for ch in chapters:
            if ch in book_theme_map:
                title = book_theme_map[ch]
            else:
                title = f"{bname} — Capítulo {ch}"
            # O título da seção do capítulo é fixado no versículo 1
            results.append((bid, ch, 1, title))

    conn.close()
    return results


def build_and_save_pericopes(
    db_out: str = "assets/pericopes.sqlite",
    ara_db: str = "assets/modules/ARA.sqlite",
) -> int:
    data = build_full_pericopes_data(ara_db)
    from scripts.ingest_pericopes import init_pericopes_db
    conn = init_pericopes_db(db_out)
    with conn:
        conn.execute("DELETE FROM pericope;")
        conn.executemany("INSERT INTO pericope (book_id, chapter, verse, title) VALUES (?, ?, ?, ?);", data)
    conn.execute("PRAGMA optimize;")
    conn.close()
    return len(data)


if __name__ == "__main__":
    count = build_and_save_pericopes()
    print(f"Base de perícopes gerada com {count} registros cobrindo todos os 66 livros.")
