import 'package:intl/intl.dart';

/// Converte a data da API (AAAA-MM-DD) para o formato brasileiro.
/// Datas antigas em outro formato (ex.: "15/11") são exibidas como vieram.
String formatarData(String? valor) {
  if (valor == null || valor.isEmpty) return '';
  final data = DateTime.tryParse(valor);
  return data == null ? valor : DateFormat('dd/MM/yyyy').format(data);
}

DateTime? lerData(String? valor) => valor == null ? null : DateTime.tryParse(valor);

/// Data no formato que a API espera (AAAA-MM-DD).
String dataParaApi(DateTime data) => DateFormat('yyyy-MM-dd').format(data);

/// Verdadeiro se a data já passou (desconsiderando o horário).
bool estaAtrasada(String? valor) {
  final data = lerData(valor);
  if (data == null) return false;
  final agora = DateTime.now();
  final hoje = DateTime(agora.year, agora.month, agora.day);
  return data.isBefore(hoje);
}
