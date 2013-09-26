import 'dart:io';

main() {
  HttpServer.bind("127.0.0.1", 8888).then((server) {
    server.listen((req) {
      req.response.write("Hello World\n");
      req.response.close();
    });

    print("Listening at http://127.0.0.1:8888/");
  });

}