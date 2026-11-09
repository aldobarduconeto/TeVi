import '../services/p2p_chat_service.dart';
import '../services/map_launcher_service.dart';
import '../services/platform_support.dart';
import '../services/media_service.dart';
import '../models/api_exception.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';

import 'theme/app_theme.dart';
import '../services/api.dart';
import 'common.dart';
import 'discover.dart';
import '../services/safe_meetup_service.dart';
import 'components/safe_meetup_dialog.dart';
import '../models/safe_meetup_model.dart';

class ConversationsScreen extends StatefulWidget {
  final Api api;
  const ConversationsScreen({super.key, required this.api});
  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  late Future<dynamic> future;
  @override
  void initState() {
    super.initState();
    future = widget.api.request('GET', '/matches');
  }

  void reload() {
    if (!mounted) return;
    final next = widget.api.request('GET', '/matches');
    setState(() {
      future = next;
    });
  }

  @override
  Widget build(BuildContext context) => ListView(
    key: const PageStorageKey('conversations-scroll'),
    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
    padding: context.pageInsets,
    children: [
      PageTitle(
        'Conexões de verdade',
        'Um oi muda tudo.',
        'O interesse já é mútuo. Agora é com vocês.',
        action: IconButton(
          onPressed: reload,
          tooltip: 'Atualizar',
          icon: Icon(Icons.refresh),
        ),
      ),
      FutureBuilder<dynamic>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return EmptyState('Não conseguimos carregar', '${snapshot.error}');
          }
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }
          final matches = snapshot.data as List;
          if (matches.isEmpty) {
            return Card(
              child: EmptyState(
                'Toda conversa tem um começo',
                'Quando uma curtida for recíproca, sua nova conexão aparece aqui.',
                icon: Icons.chat_bubble_outline,
              ),
            );
          }
          return Column(
            children: matches
                .map(
                  (m) => Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        leading: PersonAvatar(
                          Map<String, dynamic>.from(m['person']),
                        ),
                        title: Text(
                          m['person']['name'],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.place_rounded,
                                    size: 13,
                                    color: context.coral,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      'Encontrados em: ${m['region'] ?? 'Cruzamento por proximidade'}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: context.coral,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                m['last'],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.map_outlined, size: 18),
                              color: context.coral,
                              tooltip: 'Ver local no Maps',
                              onPressed: () => MapLauncherService.openMapLocation(
                                regionName: m['region'] ?? 'São Paulo',
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                            Icon(
                              Icons.chevron_right,
                              color: context.coral,
                            ),
                          ],
                        ),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => ChatScreen(
                                api: widget.api,
                                match: Map<String, dynamic>.from(m),
                              ),
                            ),
                          );
                          if (mounted) reload();
                        },
                      ),
                    ),
                  ),
                )
                .toList(),
          );
        },
      ),
    ],
  );
}

class ChatScreen extends StatefulWidget {
  final Api api;
  final Map<String, dynamic> match;
  const ChatScreen({super.key, required this.api, required this.match});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final composer = TextEditingController();
  final scroll = ScrollController();
  final player = AudioPlayer();
  AudioRecorder? recorder;
  StreamSubscription<Uint8List>? audioSubscription;
  BytesBuilder? audioBytes;
  Completer<void>? audioDone;
  Timer? polling, recordingLimit;
  List<dynamic> messages = [], calls = [];
  final Set<String> revealed = {};
  bool sending = false, recording = false, fetching = false, active = true;
  String? error;

  late final P2PChatService p2p;
  StreamSubscription<Map<String, dynamic>>? _p2pMsgSub;
  StreamSubscription<Map<String, dynamic>>? _p2pSeenSub;

  String get id => widget.match['id'];
  Map<String, dynamic> get person =>
      Map<String, dynamic>.from(widget.match['person']);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize WebRTC P2P Match Chat
    p2p = P2PChatService(
      api: widget.api,
      matchId: id,
      myUserId: widget.api.me!['id'],
      myName: widget.api.me!['name'] ?? 'Eu',
      peerUserId: person['id'],
      peerName: person['name'] ?? 'Match',
    );
    p2p.start();

    _p2pMsgSub = p2p.onMessage.listen((msg) {
      if (!mounted) return;
      setState(() {
        final existingIdx = messages.indexWhere((m) => m['id'] == msg['id']);
        if (existingIdx == -1) {
          messages.add(msg);
        }
      });
      bottom();
      if (active && msg['id'] != null) {
        p2p.sendSeen(msg['id'] as String);
      }
    });

    _p2pSeenSub = p2p.onSeen.listen((seenInfo) {
      if (!mounted) return;
      final msgId = seenInfo['messageId'] as String?;
      if (msgId == null) return;
      setState(() {
        for (var i = 0; i < messages.length; i++) {
          if (messages[i]['id'] == msgId) {
            messages[i] = {
              ...Map<String, dynamic>.from(messages[i] as Map),
              'seen': 1,
              'seen_at': seenInfo['seenAt'],
            };
          }
        }
      });
    });

    load();
    _startPolling(const Duration(seconds: 4));
  }

  void _startPolling(Duration interval) {
    polling?.cancel();
    polling = Timer.periodic(interval, (_) {
      load();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    active = state == AppLifecycleState.resumed;
    if (active) {
      p2p.setMyPresence(PeerPresence.online);
      load();
      _markUnreadAsSeen();
      _startPolling(const Duration(seconds: 4));
    } else {
      // Keep running in background whenever possible, transitioning to 'away'
      p2p.setMyPresence(PeerPresence.away);
      if (recording) {
        cancelRecording();
      }
      _startPolling(const Duration(seconds: 25));
    }
  }

  void _markUnreadAsSeen() {
    final myId = widget.api.me!['id'];
    final unread = messages
        .where((m) => m['sender'] != myId && m['seen'] != 1)
        .map((m) => m['id'] as String)
        .toList();
    if (unread.isNotEmpty) {
      p2p.sendSeenBatch(unread);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    polling?.cancel();
    recordingLimit?.cancel();
    audioSubscription?.cancel();
    _p2pMsgSub?.cancel();
    _p2pSeenSub?.cancel();
    p2p.dispose();
    recorder?.dispose();
    player.dispose();
    composer.dispose();
    scroll.dispose();
    super.dispose();
  }

  Future<void> load() async {
    if (fetching) return;
    fetching = true;
    try {
      final result = await Future.wait([
        widget.api.request('GET', '/matches/$id/messages'),
        widget.api.request('GET', '/matches/$id/calls'),
      ]);
      if (mounted) {
        final fetchedMessages = List<dynamic>.from(result[0] as List);
        final fetchedCalls = List<dynamic>.from(result[1] as List);
        final countChanged = messages.length != fetchedMessages.length ||
            calls.length != fetchedCalls.length;
        bool hasDifference = countChanged;
        if (!hasDifference && fetchedMessages.isNotEmpty) {
          final lastLocal = messages.last;
          final lastFetched = fetchedMessages.last;
          if (lastLocal['id'] != lastFetched['id'] ||
              lastLocal['seen'] != lastFetched['seen']) {
            hasDifference = true;
          }
        }
        if (hasDifference || error != null) {
          setState(() {
            messages = fetchedMessages;
            calls = fetchedCalls;
            error = null;
          });
          _markUnreadAsSeen();
          if (countChanged) bottom();
        }
      }
    } catch (e) {
      if (mounted && error == null) setState(() => error = '$e');
    } finally {
      fetching = false;
    }
  }

  Widget _buildSafeMeetupBanner(BuildContext context) {
    return ListenableBuilder(
      listenable: SafeMeetupService.instance,
      builder: (context, _) {
        final safeService = SafeMeetupService.instance;
        final partnerId = person['id'] as String? ?? id;
        if (!safeService.isMeetupActiveFor(partnerId)) {
          return const SizedBox.shrink();
        }
        final session = safeService.session!;
        final isDue = session.status == SafeMeetupStatus.checkInDue;

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isDue
                ? const Color(0x22FF3B30)
                : const Color(0x1A2196F3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDue ? const Color(0xFFFF3B30) : const Color(0xFF2196F3),
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isDue ? Icons.warning_amber_rounded : Icons.shield_rounded,
                color: isDue ? const Color(0xFFFF3B30) : const Color(0xFF2196F3),
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isDue ? 'Check-in de segurança vencido!' : 'Encontro Seguro Ativo',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDue ? const Color(0xFFFF3B30) : const Color(0xFF2196F3),
                      ),
                    ),
                    Text(
                      isDue
                          ? 'Confirme que está bem com seu PIN'
                          : 'Tempo restante: ${session.formattedRemaining}',
                      style: TextStyle(fontSize: 11, color: context.muted),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => showSafeMeetupSheet(
                  context,
                  partnerName: person['name'] ?? 'Match',
                  partnerId: partnerId,
                  region: widget.match['crossing_region'] as String?,
                ),
                child: Text(isDue ? 'Check-in' : 'Opções'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEncounterLocationBanner(BuildContext context) {
    final region =
        widget.match['region']?.toString() ?? 'Cruzamento por proximidade';
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.coral.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: context.coral.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.place_rounded, color: context.coral, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Local onde seus caminhos se cruzaram:',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: context.muted,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  region,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: context.ink,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.map_outlined,
              size: 18,
              color: context.coral,
            ),
            tooltip: 'Consultar no Maps',
            onPressed: () => MapLauncherService.openMapLocation(
              regionName: region,
            ),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(
              Icons.info_outline_rounded,
              size: 18,
              color: context.coral,
            ),
            tooltip: 'Detalhes do local',
            onPressed: () => _showEncounterDetailsDialog(context, region),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  void _showEncounterDetailsDialog(BuildContext context, String region) {
    showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Icon(Icons.place_rounded, color: context.coral, size: 44),
        title: const Text(
          'Ponto de Encontro',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              region,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.lavender,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Vocês estiveram próximos nesta mesma região física antes de dar match recíproco. O Tevi preserva sua segurança revelando apenas o ponto aproximado de cruzamento, sem expor trajetos, rotas ou coordenadas exatas.',
                style: TextStyle(
                  fontSize: 12,
                  color: context.muted,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Fechar'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.map_outlined, size: 16),
            onPressed: () {
              Navigator.pop(c);
              MapLauncherService.openMapLocation(regionName: region);
            },
            label: const Text('Ver no Maps'),
          ),
        ],
      ),
    );
  }

  void bottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (scroll.hasClients) {
      scroll.animateTo(
        scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  });

  Future<void> send(String body, [String kind = 'text']) async {
    if (body.trim().isEmpty || sending) return;
    setState(() => sending = true);
    await attempt(context, () async {
      final myId = widget.api.me!['id'];
      final now = DateTime.now().millisecondsSinceEpoch / 1000;
      final localId = 'msg_${DateTime.now().millisecondsSinceEpoch}';

      final p2pMessage = <String, dynamic>{
        'id': localId,
        'match_id': id,
        'sender': myId,
        'sender_name': widget.api.me!['name'] ?? 'Eu',
        'body': body,
        'kind': kind,
        'created': now,
        'seen': 0,
      };

      // Send strictly P2P through WebRTC data channel
      p2p.sendMessage(p2pMessage);

      // Persist in local storage
      await widget.api.request('POST', '/matches/$id/messages', {
        'body': body,
        'kind': kind,
      });

      if (kind == 'text') composer.clear();
      await load();
    });
    if (mounted) setState(() => sending = false);
  }

  Future<void> photo() async => attempt(context, () async {
    final value = await pickPhoto();
    if (value != null && context.mounted) await send(value, 'image');
  });

  Future<void> startRecording() async {
    final context = this.context;
    await attempt(context, () async {
      if (!PlatformSupport.current.microphone) {
        throw ApiException(
          'O microfone não está disponível.',
        );
      }
      recorder ??= AudioRecorder();
      if (!await recorder!.isEncoderSupported(AudioEncoder.pcm16bits)) {
        throw ApiException(
          'Este dispositivo não oferece gravação de áudio compatível.',
        );
      }
      if (!await recorder!.hasPermission()) {
        throw ApiException('Permita o microfone para gravar áudio.');
      }
      audioBytes = BytesBuilder();
      audioDone = Completer<void>();
      final stream = await recorder!.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
        ),
      );
      audioSubscription = stream.listen(
        (chunk) => audioBytes?.add(chunk),
        onDone: () {
          if (!(audioDone?.isCompleted ?? true)) audioDone!.complete();
        },
        onError: (Object e) {
          if (!(audioDone?.isCompleted ?? true)) audioDone!.complete();
          if (context.mounted) toast(context, 'Falha na gravação: $e');
        },
      );
      if (mounted) setState(() => recording = true);
      recordingLimit = Timer(const Duration(seconds: 45), () {
        if (mounted) finishRecording();
      });
    });
  }

  Future<void> cancelRecording() async {
    recordingLimit?.cancel();
    await recorder?.cancel();
    await audioSubscription?.cancel();
    audioBytes = null;
    if (mounted) setState(() => recording = false);
  }

  Future<void> finishRecording() async {
    if (!recording) return;
    setState(() => recording = false);
    recordingLimit?.cancel();
    await attempt(context, () async {
      await recorder!.stop();
      await audioDone!.future.timeout(const Duration(seconds: 3));
      final pcm = audioBytes!.takeBytes();
      if (pcm.isEmpty) return;
      final wav = ByteData(44);
      void label(int offset, String s) {
        for (int i = 0; i < s.length; i++) {
          wav.setUint8(offset + i, s.codeUnitAt(i));
        }
      }

      label(0, 'RIFF');
      wav.setUint32(4, 36 + pcm.length, Endian.little);
      label(8, 'WAVE');
      label(12, 'fmt ');
      wav.setUint32(16, 16, Endian.little);
      wav.setUint16(20, 1, Endian.little);
      wav.setUint16(22, 1, Endian.little);
      wav.setUint32(24, 16000, Endian.little);
      wav.setUint32(28, 32000, Endian.little);
      wav.setUint16(32, 2, Endian.little);
      wav.setUint16(34, 16, Endian.little);
      label(36, 'data');
      wav.setUint32(40, pcm.length, Endian.little);
      final output = BytesBuilder()
        ..add(wav.buffer.asUint8List())
        ..add(pcm);
      await send(
        'data:audio/wav;base64,${base64Encode(output.toBytes())}',
        'audio',
      );
    });
  }

  Future<void> requestCall(String kind) async {
    final context = this.context;
    if (!await confirm(
      context,
      'Convidar para chamada?',
      'A outra pessoa precisa aceitar. A chamada abre no serviço externo Jitsi; ele pode solicitar login e permissões de câmera ou microfone.',
    )) {
      return;
    }
    if (!context.mounted) return;
    await attempt(context, () async {
      await widget.api.request('POST', '/matches/$id/calls', {'kind': kind});
      await load();
    });
  }

  Future<void> openCall(dynamic call) async {
    final audio = call['kind'] == 'audio';
    final uri = Uri.parse(
      'https://meet.jit.si/${call['room']}${audio ? '#config.startWithVideoMuted=true' : ''}',
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw ApiException('Não foi possível abrir o serviço de chamada.');
    }
  }

  Widget callCard(dynamic c) {
    final incoming = c['sender'] != widget.api.me!['id'];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Icon(
              c['kind'] == 'audio'
                  ? Icons.phone_outlined
                  : Icons.videocam_outlined,
              color: context.coral,
            ),
            Text(
              c['state'] == 'accepted'
                  ? 'Chamada aceita'
                  : incoming
                  ? 'Convite para chamada'
                  : 'Aguardando aceite',
            ),
            if (c['state'] == 'pending' && incoming) ...[
              TextButton(
                onPressed: () => attempt(context, () async {
                  await widget.api.request('POST', '/calls/${c['id']}', {
                    'action': 'accepted',
                  });
                  await load();
                }),
                child: const Text('Aceitar'),
              ),
              TextButton(
                onPressed: () => attempt(context, () async {
                  await widget.api.request('POST', '/calls/${c['id']}', {
                    'action': 'declined',
                  });
                  await load();
                }),
                child: const Text('Recusar'),
              ),
            ],
            if (c['state'] == 'accepted')
              TextButton(
                onPressed: () => attempt(context, () => openCall(c)),
                child: const Text('Entrar no Jitsi'),
              ),
            TextButton(
              onPressed: () => attempt(context, () async {
                await widget.api.request('POST', '/calls/${c['id']}', {
                  'action': 'ended',
                });
                await load();
              }),
              child: const Text('Encerrar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Row(
        children: [
          Stack(
            children: [
              PersonAvatar(person, radius: 19),
              Positioned(
                bottom: 0,
                right: 0,
                child: ValueListenableBuilder<PeerPresence>(
                  valueListenable: p2p.peerPresenceNotifier,
                  builder: (_, presence, __) => Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: presence == PeerPresence.online
                          ? const Color(0xFF4CAF50)
                          : presence == PeerPresence.away
                              ? const Color(0xFFFFB300)
                              : Colors.grey,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  person['name'] ?? 'Match',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                ValueListenableBuilder<PeerPresence>(
                  valueListenable: p2p.peerPresenceNotifier,
                  builder: (_, presence, __) =>
                      ValueListenableBuilder<P2PConnectionState>(
                    valueListenable: p2p.connectionStateNotifier,
                    builder: (_, connState, __) {
                      String statusText;
                      Color statusColor;
                      if (connState != P2PConnectionState.connected) {
                        statusText = 'Conectando P2P WebRTC…';
                        statusColor = context.muted;
                      } else {
                        switch (presence) {
                          case PeerPresence.online:
                            statusText = 'Online';
                            statusColor = const Color(0xFF4CAF50);
                            break;
                          case PeerPresence.away:
                            statusText = 'Ausente (em 2º plano)';
                            statusColor = const Color(0xFFFFB300);
                            break;
                          case PeerPresence.offline:
                            statusText = 'Desconectado';
                            statusColor = context.muted;
                            break;
                        }
                      }
                      return Text(
                        statusText,
                        style: TextStyle(fontSize: 11, color: statusColor),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        ListenableBuilder(
          listenable: SafeMeetupService.instance,
          builder: (context, _) {
            final safeService = SafeMeetupService.instance;
            if (!safeService.isEnabled) {
              return const SizedBox.shrink();
            }
            final isFakePending = safeService.scheduledFakeCallCountdown != null;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () {
                    if (isFakePending) {
                      safeService.cancelScheduledFakeCall();
                      toast(context, 'Falsa chamada cancelada');
                    } else {
                      safeService.scheduleFakeCall(
                        context: context,
                        delaySeconds: 15,
                      );
                      toast(context, '📞 Chamada de escape agendada em 15s');
                    }
                  },
                  tooltip: isFakePending
                      ? 'Cancelar chamada (${safeService.scheduledFakeCallCountdown}s)'
                      : 'Falsa Chamada de Emergência (15s)',
                  icon: Icon(
                    isFakePending ? Icons.phone_in_talk : Icons.phone_callback_outlined,
                    color: isFakePending ? Colors.amber : const Color(0xFF2196F3),
                    size: 21,
                  ),
                ),
                IconButton(
                  onPressed: () => showSafeMeetupSheet(
                    context,
                    partnerName: person['name'] ?? 'Match',
                    partnerId: person['id'] ?? id,
                    region: widget.match['crossing_region'] as String?,
                  ),
                  tooltip: 'Modo Encontro Seguro',
                  icon: const Icon(Icons.shield_outlined, color: Color(0xFF2196F3)),
                ),
              ],
            );
          },
        ),
        IconButton(
          onPressed: () => requestCall('audio'),
          tooltip: 'Chamada de áudio',
          icon: const Icon(Icons.phone_outlined),
        ),
        IconButton(
          onPressed: () => requestCall('video'),
          tooltip: 'Chamada de vídeo',
          icon: const Icon(Icons.videocam_outlined),
        ),
        PopupMenuButton<String>(
          onSelected: (v) async {
            if (v == 'report') {
              reportPerson(context, widget.api, person['id']);
              return;
            }
            if (await confirm(
                  context,
                  v == 'block' ? 'Bloquear pessoa?' : 'Encerrar conexão?',
                  'Esta conversa ficará indisponível.',
                ) &&
                context.mounted) {
              await attempt(context, () async {
                await widget.api.request(
                  v == 'block' ? 'POST' : 'DELETE',
                  v == 'block'
                      ? '/people/${person['id']}/block'
                      : '/matches/$id',
                );
                if (context.mounted) Navigator.pop(context);
              });
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'report', child: Text('Denunciar')),
            PopupMenuItem(value: 'block', child: Text('Bloquear')),
            PopupMenuItem(value: 'unmatch', child: Text('Encerrar match')),
          ],
        ),
      ],
    ),
    body: Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: context.lavender,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 14, color: context.coral),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Chat Match P2P • WebRTC Direto Criptografado',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: context.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
        _buildEncounterLocationBanner(context),
        _buildSafeMeetupBanner(context),
        if (error != null)
          MaterialBanner(
            content: Text(error!),
            actions: [
              TextButton(onPressed: load, child: const Text('Tentar novamente')),
            ],
          ),
        for (final c in calls.where(
          (c) => c['state'] == 'pending' || c['state'] == 'accepted',
        ))
          callCard(c),
        Expanded(
          child: ListView(
            controller: scroll,
            padding: const EdgeInsets.all(20),
            children: [
              if (messages.isEmpty)
                const EmptyState(
                  'A primeira palavra é sua',
                  'Um interesse em comum pode render uma boa conversa via P2P.',
                ),
              for (final m in messages)
                Align(
                  alignment: m['sender'] == widget.api.me!['id']
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 480),
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: m['sender'] == widget.api.me!['id']
                          ? context.lavender
                          : context.surface,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (m['kind'] == 'text')
                          SelectableText(
                            m['body'],
                            style: const TextStyle(height: 1.5),
                          )
                        else if (m['kind'] == 'image')
                          if (revealed.contains(m['id']) ||
                              m['sender'] == widget.api.me!['id'])
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.memory(
                                base64Decode(
                                  (m['body'] as String).split(',').last,
                                ),
                                width: 250,
                                fit: BoxFit.contain,
                              ),
                            )
                          else
                            TextButton.icon(
                              onPressed: () =>
                                  setState(() => revealed.add(m['id'])),
                              icon: const Icon(Icons.visibility_outlined),
                              label: const Text('Toque para revelar a foto'),
                            )
                        else if (m['kind'] == 'audio')
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              IconButton(
                                tooltip: 'Ouvir áudio',
                                onPressed: () => attempt(
                                  context,
                                  () => player.play(
                                    BytesSource(
                                      base64Decode(
                                        (m['body'] as String).split(',').last,
                                      ),
                                      mimeType: 'audio/wav',
                                    ),
                                  ),
                                ),
                                icon: Icon(
                                  Icons.play_circle_outline,
                                  color: context.coral,
                                ),
                              ),
                              const Text('Mensagem de voz'),
                              IconButton(
                                tooltip: 'Parar áudio',
                                onPressed: player.stop,
                                icon: const Icon(Icons.stop, size: 18),
                              ),
                            ],
                          ),
                        const SizedBox(height: 5),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${DateTime.fromMillisecondsSinceEpoch(((m['created'] as num) * 1000).round()).toLocal().hour.toString().padLeft(2, '0')}:${DateTime.fromMillisecondsSinceEpoch(((m['created'] as num) * 1000).round()).toLocal().minute.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                fontSize: 9,
                                color: m['seen'] == 1 &&
                                        m['sender'] == widget.api.me!['id']
                                    ? context.coral
                                    : context.muted,
                              ),
                            ),
                            if (m['sender'] == widget.api.me!['id']) ...[
                              const SizedBox(width: 4),
                              Icon(
                                m['seen'] == 1 ? Icons.done_all : Icons.check,
                                size: 13,
                                color: m['seen'] == 1
                                    ? context.coral
                                    : context.muted,
                              ),
                              if (m['seen'] == 1) ...[
                                const SizedBox(width: 3),
                                Text(
                                  'Visualizada',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: context.coral,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (messages.length < 3)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children:
                  [
                        'Oi! Qual é seu café favorito?',
                        'Vi que gostamos de ${(person['interests'] as List).isEmpty ? 'conversar' : person['interests'][0]}. Me conta mais?',
                        'Bora trocar uma ideia? 😊',
                      ]
                      .map(
                        (s) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ActionChip(
                            label: Text(s, style: const TextStyle(fontSize: 11)),
                            onPressed: () => composer.text = s,
                          ),
                        ),
                      )
                      .toList(),
            ),
          ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: recording
                ? Row(
                    children: [
                      IconButton(
                        onPressed: cancelRecording,
                        tooltip: 'Descartar áudio',
                        icon: const Icon(Icons.delete_outline),
                      ),
                      Expanded(
                        child: Text(
                          'Gravando • até 45 segundos',
                          style: TextStyle(color: context.coral),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: finishRecording,
                        icon: const Icon(Icons.send),
                        label: const Text('Enviar áudio'),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      IconButton(
                        onPressed: sending ? null : photo,
                        tooltip: 'Enviar foto',
                        icon: const Icon(Icons.add_photo_alternate_outlined),
                      ),
                      IconButton(
                        onPressed:
                            sending || !PlatformSupport.current.microphone
                            ? null
                            : startRecording,
                        tooltip: 'Gravar áudio',
                        icon: const Icon(Icons.mic_none),
                      ),
                      Expanded(
                        child: TextField(
                          controller: composer,
                          maxLength: 2000,
                          minLines: 1,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            hintText: 'Seu próximo oi via P2P…',
                            counterText: '',
                          ),
                          onSubmitted: send,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: sending ? null : () => send(composer.text),
                        tooltip: 'Enviar mensagem',
                        icon: const Icon(Icons.arrow_upward),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    ),
  );
}
