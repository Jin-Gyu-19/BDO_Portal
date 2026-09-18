# downloads/ — 다운로드형 앱 파일 + 목록(manifest.json)

NAS 경로: `/volume1/sh-pf/docker/nginx-html/portal/downloads/`
(포털이 `/downloads/<파일명>`으로 내려받음. nginx 설정 변경 불필요. 이 폴더는 `.bat` 배포 대상이 아니며 **DSM File Station으로 직접** 올린다.)

## 새 파일 붙이는 법 (포털 재배포 없음)

1. File Station으로 이 폴더에 파일 업로드 (예: `JET_Tool_v1.3.xlsm`)
2. 같은 폴더의 `manifest.json`을 열어 해당 앱 줄을 고침 (File Station → 우클릭 → 텍스트 편집기)
3. 포털 새로고침 → 아이콘 우측 하단에 다운로드 배지가 뜸

```json
{
  "jet":     { "file": "JET_Tool_v1.3.xlsm",     "ver": "1.3" },
  "footing": { "file": "Footing_Tool_v2.0.xlsm", "ver": "2.0" }
}
```

- 키 = 포털의 앱 키(아래 표). `file` = 이 폴더 안의 파일명(버전 포함 권장). `ver`는 배지 툴팁에 `(v1.3)`로 표시(생략 가능).
- `file`을 `""`로 두면 그 앱의 배지를 끔.
- JSON 규칙: 큰따옴표만, 마지막 항목 뒤에 쉼표 없음. 형식이 깨지면 배지가 전부 안 뜨지만 포털 자체는 정상.
- 파일이 없어도 `manifest.json`이 없으면 코드에 적힌 `dl:` 항목만 쓴다.

## 앱 키

| 키 | 앱 | 키 | 앱 |
|---|---|---|---|
| `jet` | JET Tool | `footing` | Footing Tool |
| `toolkit` | Audit Toolkit | `dsdroll` | DSD 이월기입 자동화 |
| `claudeexcel` | Claude in Excel | `precheck` | 사전심리도우미 |
| `pdfguard` | PDF 증빙 위·변조 탐지 | `markettool` | 유사상장사 · 베타 분석 |
| `k1118` | K-IFRS 1118호 자동화 Tool | `xbrl` | XBRL Comparator |
| `shaudit` | SH Audit Platform | `fin` | 금융기관 조회 |
| `dart` | Open DART API 조회 | `taxagent` | TAX Agent |
| `rev` | 리뷰함 | `expense` | 경비청구 |
| `rag` | 규정 RAG | `ins` | 인사이트 |
| `erp` | ERP | `room` | 회의실 예약 |

(그 외 `notice`·`cal`·`team`·`timesheet`·`memo`·`settings`·`ai`도 키는 있으나 배지 용도가 아님)
