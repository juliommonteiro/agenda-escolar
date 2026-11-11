import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../formatadores.dart';

class NovaAtividadeScreen extends StatefulWidget {
  /// Se informado, a tela abre em modo de edição com os dados preenchidos.
  final Map<String, dynamic>? atividade;

  const NovaAtividadeScreen({super.key, this.atividade});

  @override
  State<NovaAtividadeScreen> createState() => _NovaAtividadeScreenState();
}

class _NovaAtividadeScreenState extends State<NovaAtividadeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tituloController = TextEditingController();
  final _descricaoController = TextEditingController();

  String _tipoSelecionado = 'Tarefa';
  DateTime? _dataSelecionada;

  bool get _isTarefa => _tipoSelecionado == 'Tarefa';
  bool get _isEdicao => widget.atividade != null;

  @override
  void initState() {
    super.initState();
    final atividade = widget.atividade;
    if (atividade != null) {
      _tituloController.text = atividade['titulo'] ?? '';
      final descricao = (atividade['descricao'] ?? '') as String;
      // Não preenche o campo com o texto padrão "Nenhuma descrição..."
      _descricaoController.text = descricao.startsWith('Nenhuma descrição') ? '' : descricao;
      _tipoSelecionado = atividade['tipo'] == 'Evento' ? 'Evento' : 'Tarefa';
      _dataSelecionada = lerData(atividade['data']);
    }
  }

  Color get _corPrimaria => _isTarefa ? Colors.cyan : Colors.orange;
  Color get _corGradienteFim => _isTarefa ? Colors.lightBlueAccent : Colors.deepOrangeAccent;

  Future<void> _escolherData() async {
    final agora = DateTime.now();
    final hoje = DateTime(agora.year, agora.month, agora.day);
    final dataInicial = _dataSelecionada ?? hoje;
    // Ao editar uma atividade antiga, permite manter a data que já estava salva
    final primeiraData = dataInicial.isBefore(hoje) ? dataInicial : hoje;

    final DateTime? dataEscolhida = await showDatePicker(
      context: context,
      initialDate: dataInicial,
      firstDate: primeiraData,
      lastDate: DateTime(hoje.year + 2, 12, 31),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: _corPrimaria,
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (dataEscolhida != null) {
      setState(() {
        _dataSelecionada = dataEscolhida;
      });
    }
  }

  void _salvarAtividade() {
    if (_formKey.currentState!.validate()) {
      if (_dataSelecionada == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isTarefa
                  ? 'Por favor, selecione a data de entrega.'
                  : 'Por favor, selecione a data do evento.',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }

      // Aqui a chave 'descricao' é criada e enviada junto com os dados!
      final novaAtividade = {
        'titulo': _tituloController.text.trim(),
        'tipo': _tipoSelecionado,
        'data': dataParaApi(_dataSelecionada!),
        'descricao': _descricaoController.text.trim().isEmpty
            ? 'Nenhuma descrição ou orientação adicional informada.'
            : _descricaoController.text.trim(),
      };

      Navigator.pop(context, novaAtividade);
    }
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _descricaoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_corPrimaria, _corGradienteFim],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: AppBar(
            title: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Text(
                _isEdicao
                    ? (_isTarefa ? 'Editar Tarefa' : 'Editar Evento')
                    : (_isTarefa ? 'Nova Tarefa' : 'Novo Evento Escolar'),
                key: ValueKey<String>(_tipoSelecionado),
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
            centerTitle: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 52,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(26),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final tabWidth = (constraints.maxWidth) / 2;
                    return Stack(
                      children: [
                        AnimatedAlign(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOutCubic,
                          alignment: _isTarefa ? Alignment.centerLeft : Alignment.centerRight,
                          child: Container(
                            width: tabWidth,
                            height: double.infinity,
                            decoration: BoxDecoration(
                              color: _corPrimaria,
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: [
                                BoxShadow(
                                  color: _corPrimaria.withValues(alpha: 0.35),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => setState(() => _tipoSelecionado = 'Tarefa'),
                                child: Center(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.menu_book_rounded,
                                        size: 19,
                                        color: _isTarefa ? Colors.white : Colors.grey[600],
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Tarefa',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: _isTarefa ? Colors.white : Colors.grey[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => setState(() => _tipoSelecionado = 'Evento'),
                                child: Center(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.event_note_rounded,
                                        size: 19,
                                        color: !_isTarefa ? Colors.white : Colors.grey[600],
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Evento Escolar',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: !_isTarefa ? Colors.white : Colors.grey[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _tituloController,
                keyboardType: TextInputType.text,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: _isTarefa ? 'Título da Tarefa' : 'Título do Evento',
                  prefixIcon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Icon(
                      _isTarefa ? Icons.assignment_outlined : Icons.celebration_outlined,
                      key: ValueKey<bool>(_isTarefa),
                      color: _corPrimaria,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _corPrimaria, width: 2),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Por favor, informe um título válido.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _descricaoController,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Descrição ou orientações (opcional)',
                  prefixIcon: Icon(Icons.description_outlined, color: _corPrimaria),
                  alignLabelWithHint: true,
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _corPrimaria, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: _escolherData,
                icon: Icon(Icons.calendar_month_rounded, color: _corPrimaria),
                label: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Text(
                    _dataSelecionada == null
                        ? (_isTarefa ? 'Selecionar Data de Entrega' : 'Selecionar Data do Evento')
                        : 'Data: ${DateFormat('dd/MM/yyyy').format(_dataSelecionada!)}',
                    key: ValueKey<String>(
                      '${_tipoSelecionado}_${_dataSelecionada?.toIso8601String() ?? "none"}',
                    ),
                    style: TextStyle(
                      color: _corPrimaria,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(
                    color: _dataSelecionada == null
                        ? Colors.grey.shade400
                        : _corPrimaria,
                    width: 1.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: _corPrimaria.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _salvarAtividade,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _corPrimaria,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      _isEdicao
                          ? 'SALVAR ALTERAÇÕES'
                          : (_isTarefa ? 'SALVAR TAREFA' : 'SALVAR EVENTO'),
                      key: ValueKey<String>(_tipoSelecionado),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}