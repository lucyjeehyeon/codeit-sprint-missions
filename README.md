# Codeit Sprint Missions

> 코드잇 데이터 분석가 부트캠프에서 수행한 Sprint Mission 01–17을 정리한 저장소입니다.  
> Excel 기반 데이터 분석부터 SQL, 제품 분석, 머신러닝, NLP, 시계열 예측, 클라우드 데이터 파이프라인까지  
> 학습 과정에서 수행한 개인 미션과 분석 결과를 기록했습니다.

---

## Learning Journey

스프린트 미션은 학습한 개념을 실제 데이터 분석 문제에 적용하는 개인 과제로 진행했습니다.

초반에는 Excel과 Python을 활용한 기본적인 데이터 탐색과 시각화에서 시작해,  
이후 SQL·Tableau·AARRR·Tracking Plan·Amplitude·A/B Test 등 제품 분석 영역으로 확장했습니다.

후반에는 회귀·분류·클러스터링·NLP·시계열 모델링을 적용했으며,  
마지막에는 외부 데이터를 직접 수집해 GCS → BigQuery → dbt → Python → Looker Studio로 이어지는  
클라우드 분석 파이프라인을 구축했습니다.

---

## Sprint Missions 01–17

| Mission | Topic | Main Tools |
| --- | --- | --- |
| [01. 호텔 예약 이탈 분석](./mission01_hotel-reservation-analysis) | 예약 취소·노쇼 패턴 분석 및 운영 개선안 | Excel |
| [02. Python Basics](./mission02_python-basics) | 데이터 분석을 위한 Python 기본 문법 | Python |
| [03. NumPy · Pandas · Visualization](./mission03_numpy-pandas-visualization) | 배열·데이터프레임 처리 및 시각화 | NumPy, Pandas, Matplotlib |
| [04. 건강검진 데이터 EDA](./mission04_health-check-eda) | 건강검진 데이터 전처리 및 탐색적 분석 | Python, Pandas, Plotly |
| [05. 음악 스트리밍 사용자 유형 분석](./mission05_boom-listening-dashboard) | 청취 행동 유형 분석 및 타기팅 전략 | Tableau |
| [06. SQL 음악 감상 데이터 분석](./mission06_sql-music-year-review) | 2024 음악 결산 및 사용자 행동 조회 | MySQL |
| [07. LinkedIn AARRR 지표 설계](./mission07_linkedin-aarrr-metrics) | 사용자 유형별 AARRR 핵심 지표 설계 | Product Analytics |
| [08. Styleshop Tracking Plan](./mission08_styleshop-tracking-plan) | 커머스 앱 이벤트 로그 및 Tracking Plan 설계 | Event Tracking |
| [09. 음악 스트리밍 온보딩 분석](./mission09_amplitude-onboarding-analysis) | 아하 모먼트·퍼널·리텐션·Journey 분석 | Amplitude |
| [10. 멤버십 가격 A/B Test](./mission10_ab-test-membership-pricing) | 실험 설계·통계 검정·의사결정 | Python, A/B Testing |
| [11. 자전거 대여 수요 예측](./mission11_bike-demand-prediction) | EDA 기반 Feature Engineering 및 회귀 모델링 | scikit-learn, RandomForest |
| [12. 정기예금 가입 예측](./mission12_bank-deposit-prediction) | 불균형 데이터 분류 및 Threshold Tuning | LightGBM, scikit-learn |
| [13. 신용카드 고객 세그먼테이션](./mission13_credit-card-segmentation) | PCA·Clustering 기반 고객 세그먼트 및 CRM 전략 | PCA, K-means |
| [14. SNS 텍스트 감정 분류](./mission14_text-emotion-classification) | 감정별 키워드 분석 및 텍스트 분류 | TF-IDF, Linear SVM |
| [15. BMW 글로벌 판매 예측](./mission15_bmw-sales-forecasting) | 시계열 분해 및 판매량 예측 | ARIMA, SARIMA, Prophet |
| [16. 영화 데이터 수집 및 분석](./mission16_movie-data-analysis) | Web Scraping·Open API·텍스트·시계열 분석 | BeautifulSoup, KOBIS API |
| [17. 서울시 안심택배함 분석](./mission17-seoul-locker-analysis) | 공공데이터 기반 클라우드 분석 파이프라인 및 대시보드 | GCS, BigQuery, dbt, Looker Studio |

---

## Skills Covered

### Data Analysis & Visualization

- Excel
- Pandas / NumPy
- Matplotlib / Plotly
- Tableau
- Looker Studio

### Product Analytics

- AARRR
- Metric Design
- Tracking Plan
- Funnel / Retention / Journey
- Amplitude
- A/B Testing

### SQL & Data Engineering

- MySQL
- BigQuery
- GCS
- dbt
- Public API / Web Scraping

### Machine Learning

- Linear / Logistic Regression
- Decision Tree / Random Forest
- Gradient Boosting
- XGBoost / LightGBM / CatBoost
- PCA / K-means / GMM
- Class Imbalance Handling
- Threshold Tuning

### NLP & Time Series

- TF-IDF
- Word / Character n-gram
- Linear SVM
- Word Cloud
- STL
- Exponential Smoothing
- ARIMA / SARIMA
- Prophet

---

## Selected Projects

### Mission 10 · A/B Test

멤버십 가격 표현 방식을 대상으로 실험을 설계하고,  
성공 지표인 ARPU와 구독 전환율, 가드레일 지표를 함께 검정했습니다.

전체 구독 전환보다 연간 멤버십 선택 증가가 매출 상승에 기여한다는 점을 확인하고,  
환불 문의 증가 리스크까지 고려해 후속 실험안을 제안했습니다.

→ [View Mission 10](./mission10_ab-test-membership-pricing)

### Mission 13 · Customer Segmentation

8,950명의 신용카드 고객 데이터를  
`log1p → RobustScaler → PCA → K-means` 과정으로 분석하여 5개 고객 세그먼트를 도출했습니다.

단순한 군집 분리에 그치지 않고  
세그먼트별 CRM 전략, KPI, 가드레일 및 실험 방향까지 설계했습니다.

→ [View Mission 13](./mission13_credit-card-segmentation)

### Mission 15 · Time Series Forecasting

BMW 글로벌 월별 판매 데이터를 분석해  
Holt-Winters, ARIMA, SARIMA, Prophet을 비교했습니다.

전체 판매량을 직접 예측하는 방식뿐 아니라  
지역·차종 단위 예측을 합산하는 bottom-up 방식까지 비교해 최종 예측 구조를 선정했습니다.

→ [View Mission 15](./mission15_bmw-sales-forecasting)

### Mission 17 · Cloud Data Pipeline

서울시 안심택배함 데이터를 활용해 다음과 같은 분석 파이프라인을 구축했습니다.

    Public Data
    → GCS
    → BigQuery
    → dbt
    → Python
    → BigQuery
    → Looker Studio

수요 대비 공급, 실제 이용 수준, 장기 추세, 시설별 편차를 함께 분석해  
추가 설치뿐 아니라 유지·운영 개선·재검토 등 지역별 실행 방향을 도출했습니다.

→ [View Mission 17](./mission17-seoul-locker-analysis)

---

## Repository Structure

    codeit-sprint-missions/
    │
    ├─ mission01_hotel-reservation-analysis/
    ├─ mission02_python-basics/
    ├─ mission03_numpy-pandas-visualization/
    ├─ mission04_health-check-eda/
    ├─ mission05_boom-listening-dashboard/
    ├─ mission06_sql-music-year-review/
    ├─ mission07_linkedin-aarrr-metrics/
    ├─ mission08_styleshop-tracking-plan/
    ├─ mission09_amplitude-onboarding-analysis/
    ├─ mission10_ab-test-membership-pricing/
    ├─ mission11_bike-demand-prediction/
    ├─ mission12_bank-deposit-prediction/
    ├─ mission13_credit-card-segmentation/
    ├─ mission14_text-emotion-classification/
    ├─ mission15_bmw-sales-forecasting/
    ├─ mission16_movie-data-analysis/
    ├─ mission17-seoul-locker-analysis/
    └─ README.md

각 폴더에는 미션 성격에 따라 다음 결과물이 포함되어 있습니다.

- Jupyter Notebook
- SQL / Python Code
- 분석 보고서
- Dashboard
- 개별 README
- Mentor Feedback

---

## Notes

본 저장소는 코드잇 데이터 분석가 부트캠프에서 수행한 학습 미션을 정리한 공간입니다.

각 미션의 README에는 분석 목적, 주요 과정, 핵심 결과와 함께  
멘토 피드백 및 이후 개선 방향을 기록했습니다.
