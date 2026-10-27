---
description: Oracle SQL 연습문제 출제 (예: /quiz 분석함수 Lv3, /quiz 튜닝)
---

`sql-lab` 스킬의 **A. 출제** 절차를 따라 새 문제를 낸다.

요청: $ARGUMENTS
(비어 있으면 `progress.md` 이력을 보고 다음 주제·난이도를 스스로 정한다)

필수:
- 오라클 전용 문법 기준 (`docs/ORACLE-SYNTAX.md`)
- 출제 전 정답 SQL을 `./bin/osql` 로 실제 실행해 결과 건수를 확인할 것
- 튜닝 문제면 `./bin/oplan` 으로 느린 SQL과 목표 SQL의 Buffers 차이를 확인할 것
- 문제는 **반드시 `problems/PNNN-slug.md` 별도 파일**로 만들 것. 채팅에 문제 본문을 길게 늘어놓지 않는다
- 문제 파일은 **그것만 읽고 풀 수 있게** 쓸 것: 관련 테이블·컬럼·타입·건수, 인덱스 구성,
  조인 관계, 데이터 기간, 출력 컬럼/순서/정렬, 정답 행 수, 출력 예시 몇 줄
- `answers/PNNN.sql` 과 `answers/PNNN-notes.md` 도 같이 만들되 **내용은 보여주지 않을 것**
- `attempts/PNNN/` 폴더를 만들고 그 안에 `t1.sql` **빈 제출 스텁**을 둘 것
  (주석 헤더에 출력 컬럼·정렬·행 수·제약·`/grade`, 본문은 공백)
- 채팅에는 문제 파일 경로 + 제출 스텁 경로 + 3~4줄 요약만
