# downloads/ — 다운로드형 앱 파일 + 목록(manifest.json)

NAS 경로: `/volume1/sh-pf/docker/nginx-html/portal/downloads/`
(포털이 `/downloads/<파일명>`으로 내려받음. nginx 설정 변경 불필요. 이 폴더는 `.bat` 배포 대상이 아니며 **DSM File Station으로 직접** 올린다.)

## 새 파일 붙이는 법 ① — 포털에서 (관리자, 권장)

프로필 메뉴 → **다운로드 파일 관리** (설정 창 아래쪽). 앱 줄에서 "파일 선택…" → 버전 입력 → "저장". 파일이 NAS `downloads/`에 올라가고 `manifest.json`이 갱신되어 모든 사용자에게 배지가 바로 붙는다. "해제"는 배지만 끄고(파일은 남음), "서버의 파일"에서 안 쓰는 파일을 삭제할 수 있다.
전제: NAS nginx 에 쓰기 설정 적용(`sso/README.md` 5번) + 로그인 사용자가 App Role `Admin`.

## 새 파일 붙이는 법 ② — 손으로 (File Station, 포털 재배포 없음)

1. File Station으로 이 폴더에 파일 업로드 (예: `JET_Tool_v1.3.xlsm`)
2. 같은 폴더의 `manifest.json`을 열어 해당 앱 줄을 고침 (File Station → 우클릭 → 텍스트 편집기)
3. 포털 새로고침 → 아이콘 우측 하단에 다운로드 배지가 뜸

```json
{
  "jet":     { "file": "JET_Tool_v1.3.xlsm",     "ver": "1.3" },
  "footing": { "file": "Footing_Tool_v2.0.xlsm", "ver": "2.0" }
}
```

- 항목에 `name`·`sub`를 넣으면 **앱 이름·부제가 바뀜**(모든 사용자). 예: `"toolkit": { "name": "Staff Toolkit", "sub": "원장가공 · 리스계산" }`. 파일 없이 이름만 있어도 됨. 포털 관리 화면의 ✎ 버튼이 이걸 씀.
- 키 = 포털의 앱 키(아래 표). `file` = 이 폴더 안의 파일명(버전 포함 권장). `ver`는 배지 툴팁에 `(v1.3)`로 표시(생략 가능).
- `file`을 `""`로 두면 그 앱의 배지를 끔.
- JSON 규칙: 큰따옴표만, 마지막 항목 뒤에 쉼표 없음. 형식이 깨지면 배지가 전부 안 뜨지만 포털 자체는 정상.
- 파일이 없어도 `manifest.json`이 없으면 코드에 적힌 `dl:` 항목만 쓴다.

## 앱 키

| 키 | 앱 | 키 | 앱 |
|---|---|---|---|
| `jet` | JET Tool | `footing` | Footing Tool |
| `toolkit` | Staff Toolkit | `dsdroll` | DSD 이월기입 자동화 |
| `claudeexcel` | Claude in Excel | `precheck` | 사전심리도우미 |
| `pdfguard` | PDF 증빙 위·변조 탐지 | `markettool` | 베타·주가변동성 산출 도구 |
| `k1118` | K-IFRS 1118호 자동화 Tool | `xbrl` | XBRL Comparator |
| `ifrs18wp` | IFRS18_wp | `startend` | Start and End |
| `qms` | QMS 자동화 | `prerisk` | 계약전위험평가조서 자동화 도구 |
| `enreport` | 영문보고서 초안 작성 자동화 Tool | `vuln` | 취약점 진단 |
| `koaudrep` | 국문감사보고서 대사검증 | `enaudrep` | 영문감사보고서 대사검증 |
| `enwriter` | 영문감사보고서 자동작성 | | |
| `shaudit` | SH Audit Platform | `fin` | 금융기관 조회 |
| `dart` | Open DART API 조회 | `taxagent` | TAX Agent |
| `rev` | 리뷰함 | `expense` | 경비청구 |
| `rag` | 규정 RAG | `ins` | 인사이트 |
| `erp` | ERP | `room` | 회의실 예약 |

(그 외 `notice`·`cal`·`team`·`timesheet`·`memo`·`settings`·`ai`도 키는 있으나 배지 용도가 아님)
