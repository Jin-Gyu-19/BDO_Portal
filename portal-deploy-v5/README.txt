============================================================
  SH Portal v5 배포 안내
  성현회계법인 AX 대전환 프로젝트
============================================================

이 폴더에 들어있는 파일:
  - index.html      : SH Portal (메인 진입점)
  - audit.html      : SH Audit Platform v4 (620KB)
  - ifrs18.html     : K-IFRS 1118호 재무제표 분석기 v1.0 (279KB)
  - default.conf    : Nginx 라우팅 설정 (v5 포털 통합)
  - deploy-v5.sh    : 자동 배포 스크립트
  - README.txt      : 이 안내 파일


[이번 배포의 핵심 변경사항]

  ★ SH Portal이 메인 진입점(/)으로 변경!
  - 기존: http://192.168.100.25:8080/ → 간단 대시보드
  - 변경: http://192.168.100.25:8080/ → SH Portal (로그인 → 대시보드 → 앱)

  ★ SH Audit Platform이 포털 안에서 열림!
  - 포털의 "SH Audit Platform" 클릭 → 포털 상단바 유지 + 앱이 내부에서 로딩
  - "포털로 돌아가기" 버튼으로 다시 포털로 복귀

  ★ K-IFRS 1118호 분석기도 포털 안에서 열림!
  - 포털의 "K-IFRS 1118호 분석기" 클릭 → 동일 방식으로 내부 로딩
  - BDO Red 브랜드 색상 적용된 전용 앱


[배포 방법]

1. 이 폴더(portal-deploy-v5)를 NAS에 업로드합니다.
   위치: /volume1/sh-pf/docker/sh-platform/portal-deploy-v5/

   업로드 방법 (택1):
   - DSM File Station 웹에서 드래그&드롭
   - SCP: scp -P 3907 -r portal-deploy-v5/ jinkyu.kim@192.168.100.25:/volume1/sh-pf/docker/sh-platform/

2. SSH로 NAS에 접속합니다.
   ssh jinkyu.kim@192.168.100.25 -p 3907

3. 배포 스크립트를 실행합니다.
   cd /volume1/sh-pf/docker/sh-platform/portal-deploy-v5
   chmod +x deploy-v5.sh
   ./deploy-v5.sh

4. 완료! 브라우저에서 확인합니다.
   http://192.168.100.25:8080/


[배포 후 URL 정리]

  http://192.168.100.25:8080/          ★ SH Portal (메인 진입점)
  http://192.168.100.25:8080/audit/    SH Audit Platform v4 (iframe용)
  http://192.168.100.25:8080/ifrs18/   K-IFRS 1118호 분석기 (iframe용)
  http://192.168.100.25:8080/data/     재무제표 구조화 (Streamlit)
  http://192.168.100.25:8080/health    헬스체크


============================================================
  문의: 윤길배 대표 (setonyoon@gmail.com)
============================================================
