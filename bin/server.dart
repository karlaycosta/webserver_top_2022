import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_static/shelf_static.dart';
import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

//https://karlaycosta.cloudns.nz
// Define a porta que o servidor irá escutar
const port = 8080;
void main(List<String> args) async {
  sqfliteFfiInit();
  var databaseFactory = databaseFactoryFfi;
  final path = '${Directory.current.path}${Platform.pathSeparator}ceps.db';
  final db = await databaseFactory.openDatabase(path);

  // Pega o ip local da máquina
  final ip = InternetAddress.anyIPv4;

  // Servidor de aquivos estáticos.
  // Os arquivos estão na pasta [web].
  final staticFileHandler = createStaticHandler(
    'web',
    defaultDocument: 'index.html',
  );

  // Cria um objeto do tipo Rota
  final rotas = Router();
  // Adiciona uma rota do GET que retorna o resultado
  // da pesquisa no banco de dados usando o termo
  rotas.get('/ws/<termo>', (Request request, String termo) async {
    final res = await consultar(Uri.decodeFull(termo), db);
    return Response.ok(res, headers: {'Content-Type': 'application/json'});
  });
  // Cria um objeto Cascade para sequenciar as requisições
  final sequencia = Cascade().add(staticFileHandler).add(rotas).handler;
  final handler = Pipeline()
      // .addMiddleware(logRequests())
      .addMiddleware(seguranca())
      .addMiddleware(corsHeaders(headers: {'ACCESS_CONTROL_ALLOW_ORIGIN': '*'}))
      .addHandler(sequencia);
  // Inicia o servidor passando um manipulador (Handler),
  // ip local e a porta do serviço.
  final server = await serve(handler, ip, port);
  print('Servidor ouvindo a prota ${server.port}...');
}

Future<String> consultar(String termo, Database db, {int limit = 20}) async {
  print(termo);
  if (termo.length <= 1) {
    return 'A consulta tem um termo superior a um caractere!';
  }
  final res = await db.rawQuery(
      '''
    select cep, 
        highlight(consulta, 1 , '<mark>', '</mark>') uf,
        highlight(consulta, 2 , '<mark>', '</mark>') cidade,
        highlight(consulta, 3 , '<mark>', '</mark>') bairro,
        highlight(consulta, 4 , '<mark>', '</mark>') logradouro
    from consulta 
    where consulta 
    match '$termo*' 
    order by rank
    limit $limit;
''');
  return jsonEncode(res.length == 1 ? res.first : res);
}

Middleware seguranca() {
  return (handle) {
    return (request) {
      final info = request.context['shelf.io.connection_info'] as HttpConnectionInfo;
      print(info.remoteAddress);
      // // Senha tem que ser ifpa2022
      // final pass = request.headers['password'];
      // if (pass == null || pass != 'ifpa2022') {
      //   return Response(401, body: 'Não autenticao');
      // }
      // Passar para frente
      return handle(request);
    };
  };
}

