// 데이터 제보 — 공개 데이터 저장소(mdefitko777/Gunpula)에 GitHub 이슈를 미리 채워 브라우저로 연다.
// 서버도 계정도 필요 없다: 사람이 GitHub 에서 내용을 보고 "Submit" 을 누를 때만 올라간다.
// 상품 상세(정보 오류) · 모르는 바코드(없는 상품) · 도감(정리 요청)이 같이 쓴다.
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'l10n/l10n.dart';
import 'models.dart';
import 'theme.dart';
import 'widgets.dart';

/// 이슈를 올리는 공개 데이터 저장소
const dataIssueRepo = 'https://github.com/mdefitko777/Gunpula/issues/new';

/// 무엇을 제보하나
enum ReportKind {
  /// 있는 상품의 정보가 틀림 (상품 상세)
  wrongInfo,

  /// 상품이 아예 없음 (모르는 바코드 · 검색해도 없음)
  missingKit,

  /// 도감 정리 요청 (기체 연결 · 이름)
  guide,
}

/// 고를 수 있는 "무엇이 틀렸나" (짧게) — 이슈에는 한국어 그대로 (데이터 저장소 쪽이 읽는다), 시트에는 tr
List<String> reportChoices(ReportKind kind) => switch (kind) {
  ReportKind.wrongInfo => const ['이름', '가격', '발매일', '사진', '작품 · 라인', '기타'],
  ReportKind.missingKit => const ['상품이 없어요', '바코드가 다른 상품', '기타'],
  ReportKind.guide => const ['기체 연결', '기체 이름', '빠진 기체', '기타'],
};

/// 이슈 제목 + 본문 → GitHub "새 이슈" 주소 (본문은 사람이 보고 고칠 수 있다)
Uri dataIssueUri({
  required ReportKind kind,
  Kit? kit,
  String unitName = '',
  String barcode = '',
  String problem = '',
  String detail = '',
}) {
  // 이슈는 Gunpula 데이터(names.ko 기준)를 고치는 사람이 읽는다 — 화면 언어와 상관없이 한국어 이름, 중국어 이름은 본문에 따로
  final what = kit?.nameKo ?? (unitName.isNotEmpty ? unitName : (barcode.isNotEmpty ? '바코드 $barcode' : '상품'));
  final tag = switch (kind) {
    ReportKind.wrongInfo => '정보 오류',
    ReportKind.missingKit => '없는 상품',
    ReportKind.guide => '도감 정리',
  };
  final title = '[$tag] $what${problem.isEmpty ? '' : ' — $problem'}';
  final body = [
    if (kit != null) ...[
      '- kit_id: `${kit.id}`',
      '- 이름: ${kit.nameKo}',
      if (kit.nameJa.isNotEmpty) '- 일본어 이름: ${kit.nameJa}',
      if (kit.nameZh.isNotEmpty) '- 중국어 이름: ${kit.nameZh}',
      if (kit.officialUrl.isNotEmpty) '- 공식 페이지: ${kit.officialUrl}',
      if (kit.jan.isNotEmpty) '- JAN: ${kit.jan}',
    ],
    if (unitName.isNotEmpty) '- 기체: $unitName',
    if (barcode.isNotEmpty) '- 바코드: `$barcode`',
    if (problem.isNotEmpty) '- 무엇이: $problem',
    '',
    if (detail.trim().isNotEmpty) detail.trim() else '(자세한 내용)',
    '',
    '_Hobby Atlas 앱에서 보냄_',
  ].join('\n');
  return Uri.parse(dataIssueRepo).replace(queryParameters: {'title': title, 'body': body});
}

/// 제보 시트: 무엇이 틀렸나(하나 고르기) + 한 줄 설명 → GitHub 새 이슈(브라우저). 열었으면 true
Future<bool> reportDataIssue(
  BuildContext context, {
  Kit? kit,
  String unitName = '',
  String barcode = '',
  ReportKind kind = ReportKind.wrongInfo,
}) async {
  final picked = await showGpSheet<(String, String)>(
    context,
    tall: true,
    builder: (_) => _ReportSheet(kind: kind, subject: kit?.name ?? (unitName.isNotEmpty ? unitName : barcode)),
  );
  if (picked == null || !context.mounted) return false;
  final uri = dataIssueUri(
    kind: kind,
    kit: kit,
    unitName: unitName,
    barcode: barcode,
    problem: picked.$1,
    detail: picked.$2,
  );
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (context.mounted) showToast(context, ok ? tr('GitHub 에서 확인하고 보내 주세요') : tr('GitHub 를 열지 못했어요'));
  return ok;
}

class _ReportSheet extends StatefulWidget {
  const _ReportSheet({required this.kind, required this.subject});
  final ReportKind kind;
  final String subject;

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  late String _problem = reportChoices(widget.kind).first;
  final _detail = TextEditingController();

  @override
  void dispose() {
    _detail.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.viewInsetsOf(context).bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            tr('제보'),
            subtitle: widget.subject,
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
            trailing: const Icon(Icons.flag_outlined, size: Gp.iM, color: Gp.muted),
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final c in reportChoices(widget.kind))
                ChoiceChip(
                  label: Text(tr(c)),
                  selected: c == _problem,
                  showCheckmark: false,
                  selectedColor: Gp.accent.withValues(alpha: 0.14),
                  side: BorderSide(color: c == _problem ? Gp.accent : Gp.line),
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(Gp.rSmall))),
                  onSelected: (_) => setState(() => _problem = c), // STATE: 무엇이 틀렸나
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _detail,
            maxLines: 3,
            minLines: 1,
            decoration: InputDecoration(hintText: tr('맞는 값 · 출처 (선택)'), border: const OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, (_problem, _detail.text)),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46)),
            icon: const Icon(Icons.north_east, size: Gp.iM),
            label: Text(tr('GitHub 에서 보내기')),
          ),
        ],
      ),
    );
  }
}
