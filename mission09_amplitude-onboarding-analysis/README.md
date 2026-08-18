# Sprint Mission 09. 음악 스트리밍 신규 유저 온보딩 분석

> Amplitude의 Media Streaming 데이터를 활용해 서비스 이용 현황을 진단하고,  
> 신규 유저가 핵심 가치 경험까지 도달하는 과정을 분석한 미션입니다.

---

## Project Summary

| 구분 | 내용 |
| --- | --- |
| 분석 대상 | 음악 스트리밍 서비스 |
| 분석 도구 | Amplitude |
| 분석 데이터 | Media Streaming Demo Data |
| 분석 기간 | 2025년 1월 ~ 12월 |
| 주요 분석 | 유저 현황, Engagement, Retention, Funnel, Journeys, Lifecycle |
| 핵심 주제 | 신규 유저 온보딩 및 Lock-in 행동 분석 |

---

## Analysis

- 월별·일별 활성 유저 및 이용 빈도 확인
- Platform, PLAN_TYPE, 유입 채널별 유저 구성 분석
- 주요 이벤트의 Adoption·Frequency 및 고착도 비교
- 방문과 콘텐츠 재생 기준 리텐션 비교
- 신규 유저 첫 재생 퍼널 분석
- 첫 재생 이후 즐겨찾기·추천 재생·플레이리스트 팔로우 전환 비교
- Journeys를 활용한 실제 신규 유저 행동 경로 확인
- 유입 채널·플랫폼별 온보딩 전환율 비교
- Lifecycle을 활용한 신규·기존·재활성·휴면 유저 흐름 확인

---

## Key Findings

- `Play Song or Video`를 서비스의 **1차 아하 모먼트**로 정의
- `Favorite Song or Video`를 첫 재생 이후의 **Lock-in 행동 후보**로 정의
- 가입 후 첫 재생까지의 최종 전환율은 약 **69.2%**
- 가장 큰 초기 이탈은 `User Sign Up → Main Landing Screen` 구간에서 발생
- 첫 재생 후 즐겨찾기까지의 최종 전환율은 **52.0%**
- 추천 재생은 **30.6%**, 플레이리스트 팔로우는 **14.9%**로 상대적으로 낮음
- 유입 채널과 주요 플랫폼별 전환율 차이는 크지 않아 특정 세그먼트보다 공통 온보딩 흐름의 개선이 우선

---

## Recommendations

1. 가입 완료 후 메인 화면까지의 진입 과정 단순화
2. 신규 유저가 첫 콘텐츠 재생까지 빠르게 도달하도록 탐색 흐름 개선
3. 첫 재생 이후 즐겨찾기를 자연스럽게 유도
4. 즐겨찾기로 취향 데이터가 축적된 이후 추천 콘텐츠와 플레이리스트 제안

---

## File

- [Analysis Report](./music_streaming_onboarding_analysis_report.pdf)
