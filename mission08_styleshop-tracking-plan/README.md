# Sprint Mission 08. Styleshop Tracking Plan

> 가상의 커머스 앱 Styleshop의 메인·카테고리 페이지를 대상으로  
> 주요 지표를 측정하기 위한 이벤트 로그와 Tracking Plan을 설계한 미션입니다.

---

## Project Summary

| 구분 | 내용 |
| --- | --- |
| 서비스 | Styleshop |
| 분석 영역 | 메인 페이지, 카테고리 페이지 |
| 주요 작업 | 이벤트 정의, 이벤트 속성 설계, Trigger 정의 |
| 주요 지표 | 방문 빈도, CTR, 상품 탐색, 스크롤 깊이, 체류 시간 |
| 주요 산출물 | Tracking Plan Excel, PDF |

---

## Tracking Design

주어진 화면에서 필요한 지표를 계산할 수 있도록  
페이지 방문부터 노출·클릭·스크롤·이탈까지 사용자 행동 로그를 설계했습니다.

- 메인/카테고리 페이지 방문 및 이탈
- 메인 배너 노출·클릭
- 카테고리 퀵메뉴 노출·클릭
- 영역별 상품 노출·클릭
- 상품의 노출 순서 및 영역 정보
- 무료배송·번개배송 배지 여부
- 상품 할인율
- 인기 브랜드 및 인기 코디 배너 행동
- 카테고리별 상품 리스트 스크롤 깊이

추가로 페이지 체류 시간과 상품 탐색 깊이를 측정할 수 있도록  
`page_exit`, `item_scroll`, `scroll_depth` 로그를 설계했습니다.

---

## Mentor Feedback

노출 순서를 모든 콘텐츠에서 공통으로 `index`라는 이름으로 사용하면  
배너·상품·코디 간 의미가 혼동될 수 있다는 피드백을 받았습니다.

향후에는 다음과 같이 이벤트 대상에 따라 속성명을 구체화할 수 있습니다.

- `banner_index`
- `product_index`
- `outfit_index`

또한 일부 이벤트의 `event_attribute`가 비어 있어  
분석 시 식별 정보가 부족할 가능성이 있으므로, 필요한 식별 속성을 명확히 정의하는 것이 개선 방향입니다.

---

## Files

- [Tracking Plan Excel](./styleshop_tracking_plan.xlsx)
- [Tracking Plan PDF](./styleshop_tracking_plan.pdf)
