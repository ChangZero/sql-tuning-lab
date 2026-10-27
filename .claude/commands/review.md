---
description: 임의의 SQL을 실행계획 기준으로 리뷰 (문제와 무관하게)
---

대상 SQL: $ARGUMENTS
(파일 경로면 그 파일을, SQL 문자열이면 그대로)

1. `./bin/oplan` 으로 2회 실행해 실측 실행계획을 얻는다
2. `docs/TUNING-PLAYBOOK.md` 순서(A-Rows↔E-Rows → Starts → Buffers → Pstart/Pstop)로 진단
3. 개선안을 오라클 문법으로 작성해 다시 `./bin/oplan` 으로 측정하고 Before/After Buffers 를 나란히 제시
4. 인덱스 추가를 제안한다면 만들지 말고 DDL 만 제시한다 (60GB 스키마 — 생성 비용이 크다)
