import json
from pathlib import Path

pericopes = {
    # Mateus (40)
    "40:9": "A Cura do Paralítico e o Chamado de Mateus", # 8
    "40:10": "A Escolha e o Envio dos Doze Apóstolos", # 8
    "40:11": "O Testemunho de Jesus Acerca de João Batista", # 8
    "40:12": "O Senhor do Sábado e o Reino Inabalável", # 8
    "40:15": "A Tradição dos Anciãos e a Verdadeira Pureza", # 8
    "40:18": "O Maior no Reino dos Céus e o Perdão", # 9
    "40:19": "O Ensino Sobre o Matrimônio e o Jovem Rico", # 9
    "40:20": "Os Trabalhadores na Vinha e o Serviço Cristão", # 8
    "40:21": "A Entrada Triunfal de Jesus em Jerusalém", # 7
    "40:22": "A Parábola das Bodas e o Grande Mandamento", # 8
    "40:23": "As Advertências aos Escribas e Fariseus Hipócritas", # 7
    "40:25": "As Parábolas das Dez Virgens e dos Talentos", # 8

    # Marcos (41)
    "41:3": "A Escolha dos Doze Apóstolos no Monte", # 7
    "41:6": "A Rejeição em Nazaré e a Morte de João", # 9
    "41:7": "O Puro e o Impuro Segundo o Coração", # 8
    "41:9": "A Transfiguração de Jesus no Monte Santo", # 7
    "41:10": "O Casamento Cristão e a Grandeza no Servir", # 8
    "41:12": "Os Lavradores Maus e a Oferta da Viúva", # 8
    "41:13": "O Sermão Profético e os Sinais dos Tempos", # 8
    "41:14": "A Última Ceia e a Agonia no Getsêmani", # 8
    "41:15": "A Crucificação, Morte e Sepultamento de Jesus", # 7

    # Lucas (42)
    "42:3": "A Pregação no Deserto e a Genealogia Messiânica", # 8
    "42:5": "A Pesca Maravilhosa e o Chamado dos Discípulos", # 8
    "42:6": "O Sermão do Monte e a Escolha Apostólica", # 8
    "42:7": "A Fé do Centurião e a Graça Perdoadora", # 8
    "42:8": "O Semeador e a Tempestade Acalmada no Mar", # 8
    "42:9": "A Missão dos Doze e a Gloriosa Transfiguração", # 8
    "42:11": "O Pai-Nosso e a Oração com Perseverança", # 7
    "42:12": "A Advertência Contra a Avareza e a Ansiedade", # 8
    "42:13": "O Chamado ao Arrependimento e a Porta Estreita", # 8
    "42:14": "O Grande Banquete e o Preço do Discipulado", # 8
    "42:16": "O Administrador Infiel e o Rico e Lázaro", # 8
    "42:17": "O Dever do Perdão e a Vinda do Reino", # 9
    "42:18": "O Fariseu e o Publicano e o Governante", # 8
    "42:20": "A Autoridade de Jesus Perante os Líderes Religiosos", # 8
    "42:21": "A Oferta da Viúva e a Vinda Gloriosa", # 8
    "42:22": "A Santa Ceia e a Agonia no Getsêmani", # 8
    "42:23": "O Julgamento, Morte na Cruz e Sepultamento de Cristo", # 9

    # João (43)
    "43:5": "A Cura em Betesda e o Testemunho Divino", # 8
    "43:7": "A Fonte de Água Viva na Festa Sagrada", # 8
    "43:9": "A Cura do Cego de Nascença em Siloé", # 8
    "43:12": "A Entrada Triunfal e a Promessa de Glória", # 8
    "43:13": "O Lava-Pés e o Mandamento do Amor Fraternal", # 8
    "43:16": "A Promessa do Consolador e a Vitória Final", # 8
    "43:18": "A Prisão de Jesus e o Julgamento Perante Pilatos", # 9
    "43:19": "A Crucificação e a Redenção Consumada na Cruz", # 8

    # Atos dos Apóstolos (44)
    "44:4": "A Prisão dos Apóstolos e a Oração Unânime", # 8
    "44:5": "Ananias e Safira e o Livramento dos Apóstolos", # 8
    "44:6": "A Escolha dos Sete Diáconos e Santo Estêvão", # 8
    "44:8": "O Evangelho em Samaria e a Conversão do Etíope", # 9
    "44:11": "A Igreja em Antioquia e o Evangelho aos Gentios", # 9
    "44:12": "O Livramento Milagroso de Pedro da Prisão", # 7
    "44:13": "A Primeira Viagem Missionária e a Palavra Pregada", # 8
    "44:14": "O Ministério Missionário em Listra e Derbe", # 7
    "44:15": "O Concílio de Jerusalém e a Graça Salvador", # 8
    "44:18": "O Ministério de Paulo em Corinto e Éfeso", # 8
    "44:19": "O Avivamento em Éfeso e o Conflito com Artêmis", # 9
    "44:20": "A Despedida de Paulo aos Presbíteros de Éfeso", # 8
    "44:21": "A Chegada de Paulo a Jerusalém e sua Prisão", # 9
    "44:22": "A Defesa de Paulo Diante do Povo Judeu", # 8
    "44:23": "O Testemunho Diante do Sinédrio e a Providência", # 8
    "44:24": "A Defesa de Paulo Diante do Governador Félix", # 8
    "44:25": "O Apelo Solene de Paulo ao Tribunal Romano", # 8
    "44:26": "A Defesa de Paulo Diante do Rei Agripa", # 8

    # Romanos (45)
    "45:2": "O Justo Juízo de Deus Sem Parcialidade Humana", # 8
    "45:4": "A Justificação Pela Fé no Exemplo de Abraão", # 8
    "45:6": "Mortos Para o Pecado e Vivos Para Deus", # 8
    "45:7": "A Luta Espiritual Contra o Pecado Interior", # 7
    "45:9": "A Soberania de Deus e a Eleição de Israel", # 9
    "45:10": "A Mensagem da Justiça Pela Fé em Cristo", # 8
    "45:11": "O Remanescente Fiel e a Oliveira dos Gentios", # 8
    "45:13": "A Submissão às Autoridades e a Dívida do Amor", # 9
    "45:14": "A Convivência Fraternal e o Respeito aos Fracos", # 8
    "45:15": "O Ministério Apostólico aos Gentios e Planos Missionários", # 8
    "45:16": "Saudações Finais e Advertência Contra as Divisões", # 7

    # 1 Coríntios (46)
    "46:2": "A Verdadeira Sabedoria Revelada Pelo Espírito Santo", # 7
    "46:4": "Os Servos de Cristo e os Despenseiros Divinos", # 8
    "46:5": "A Disciplina Eclesiástica e a Pureza Moral Cristã", # 8
    "46:6": "Os Litígios Fraternais e o Corpo como Santuário", # 8
    "46:7": "Orientações Sagradas Sobre o Casamento e o Celibato", # 8
    "46:8": "A Liberdade Cristã e a Sensibilidade Fraterna Necessária", # 8
    "46:9": "Os Direitos Apostólicos e a Autodisciplina na Fé", # 8
    "46:10": "Exemplos do Deserto e a Fuga da Idolatria", # 8
    "46:12": "A Diversidade dos Dons e o Corpo Unido", # 8
    "46:14": "A Edificação da Igreja e a Ordem no Culto", # 9
    "46:16": "A Ajuda Fraternal e as Recomendações Apostólicas Finais", # 8

    # 2 Coríntios (47)
    "47:1": "O Deus Consolador em Nossas Aflições e Sofrimentos", # 8
    "47:2": "O Triunfo em Cristo e o Perdão Fraterno", # 8
    "47:3": "A Superioridade da Nova Aliança Gravada no Espírito", # 8
    "47:6": "O Ministério da Reconciliação e a Santidade Prática", # 8
    "47:7": "A Tristeza Segundo Deus e o Verdadeiro Arrependimento", # 8
    "47:8": "A Generosidade Cristã e a Coleta dos Santos", # 8
    "47:9": "A Semeadura Alegre e a Colheita de Graça", # 8
    "47:10": "O Combate Espiritual e a Autoridade de Paulo", # 8
    "47:11": "O Falso Apostolado e os Sofrimentos de Paulo", # 8
    "47:13": "O Exame de Consciência e a Bênção Trinitária", # 8

    # Gálatas (48)
    "48:1": "O Evangelho Puro Contra Outras Doutrinas Humanas", # 7
    "48:3": "A Fé em Cristo e a Herança Abraâmica", # 8
    "48:4": "A Filiação Divina e a Liberdade da Graça", # 8
    "48:6": "A Semeadura Espiritual e o Socorro Fraternal Mútuo", # 8

    # Efésios (49)
    "49:3": "O Mistério Revelado da Graça aos Povos Gentílicos", # 8
    "49:4": "A Unidade do Espírito e a Vida Nova", # 8
    "49:5": "O Andar em Luz e a Santidade Familiar", # 8

    # Filipenses (50)
    "50:3": "O Conhecimento Sublime de Cristo e o Alvo Celestial", # 9

    # Colossenses (51)
    "51:2": "A Plenitude em Cristo Contra Vãs Filosofias Humanas", # 8
    "51:4": "A Vida de Oração e as Saudações Fraternais", # 8

    # 1 Tessalonicenses (52)
    "52:1": "O Exemplo Louvável de Fé Viva e Esperança", # 8
    "52:2": "O Cuidado Pastoral e o Amor Pela Igreja", # 8
    "52:3": "O Alívio Pastoral e a Firmeza na Fé", # 8

    # 2 Tessalonicenses (53)
    "53:1": "A Vinda Gloriosa de Jesus e o Justo Julgamento", # 9
    "53:3": "A Oração Pela Palavra e a Disciplina Cristã", # 8

    # 1 Timóteo (54)
    "54:1": "A Sã Doutrina e o Grande Ministério Pastoral", # 8
    "54:3": "As Qualificações Morais dos Bispos e dos Diáconos", # 8
    "54:4": "A Apostasia Vindoura e a Prática da Piedade", # 8
    "54:5": "O Cuidado com Viúvas e a Honra aos Presbíteros", # 9

    # 2 Timóteo (55)
    "55:1": "O Espírito de Coragem e o Testemunho Fiel", # 8
    "55:2": "O Bom Soldado de Cristo e o Obreiro Fiel", # 9

    # Tito (56)
    "56:1": "A Escolha dos Presbíteros e o Repúdio aos Erros", # 9
    "56:3": "A Graça que Salva e as Boas Obras", # 8

    # Hebreus (58)
    "58:2": "A Salvação Sublime e a Humilhação Redentora de Cristo", # 8
    "58:3": "A Superioridade de Cristo Sobre Moisés e Advertência", # 8
    "58:5": "O Sacerdócio de Cristo Segundo a Ordem Eterna", # 8
    "58:6": "O Crescimento Espiritual e a Firme Esperança Divina", # 8
    "58:8": "O Mediador da Nova e Superior Aliança Celestial", # 8
    "58:9": "O Sacrifício Perfeito de Cristo no Altar Celestial", # 8
    "58:10": "A Perfeição do Sangue Redentor e a Perseverança", # 8
    "58:13": "Exortações Finais à Pureza, Amor Fraterno e Santidade", # 8

    # Tiago (59)
    "59:3": "O Controle da Língua e a Sabedoria Celestial", # 8
    "59:4": "A Amizade do Mundo e a Submissão Humilde", # 9
    "59:5": "A Paciência no Sofrimento e a Oração da Fé", # 9

    # 1 Pedro (60)
    "60:3": "O Casamento Cristão e o Sofrimento Pela Justiça", # 8
    "60:4": "A Vida Para a Vontade Divina e os Sofrimentos", # 9
    "60:5": "O Pastoreio Fiel e a Resistência Contra o Adversário", # 9

    # 2 Pedro (61)
    "61:2": "A Advertência Severa Contra os Falsos Mestres Apóstatas", # 8

    # 1 João (62)
    "62:2": "Cristo, Nosso Advogado Justo e o Mandamento do Amor", # 9
    "62:5": "A Vitória Que Vence o Mundo Pela Fé Convicção", # 9

    # Apocalipse (66)
    "66:6": "Os Cavaleiros do Juízo e os Primeiros Selos", # 8
    "66:8": "O Sétimo Selo e as Primeiras Trombetas Divinas", # 8
    "66:9": "A Praga dos Gafanhotos e os Cavaleiros Mortíferos", # 8
    "66:10": "O Anjo Majestoso e o Pequeno Livro Doce", # 8
    "66:13": "A Besta do Mar e o Falso Profeta Terreno", # 9
    "66:15": "O Cântico de Moisés e as Sete Taças", # 8
    "66:16": "O Derramamento das Sete Taças do Julgamento Divino", # 8
    "66:17": "O Julgamento da Babilônia e o Mistério da Fera", # 9
    "66:18": "A Queda Definitiva e o Lamento Sobre Babilônia", # 8
}

missing = json.load(open('/home/loko/Documentos/ufMA/Hinário_App/scripts/missing_nt.json'))

missing_keys = set(f"{x[0]}:{x[2]}" for x in missing)
pericope_keys = set(pericopes.keys())

diff1 = missing_keys - pericope_keys
diff2 = pericope_keys - missing_keys

if diff1 or diff2:
    print(f"Mismatch! Missing: {diff1}, Extra: {diff2}")
    exit(1)

# Validate word count (3 to 9 words) and no 'Capítulo'
invalid = []
for k, v in pericopes.items():
    words = v.split()
    if not (3 <= len(words) <= 9):
        invalid.append((k, v, len(words), "Word count"))
    if 'capítulo' in v.lower():
        invalid.append((k, v, len(words), "Has Capitulo"))

if invalid:
    print("Invalid pericopes found:")
    for inv in invalid:
        print(inv)
    exit(1)

out_path = Path(__file__).resolve().parent / 'data' / 'pericopes_nt.json'
with open(out_path, 'w', encoding='utf-8') as f:
    json.dump(pericopes, f, ensure_ascii=False, indent=2)

print(f"Successfully validated and saved {len(pericopes)} pericopes to {out_path}!")
