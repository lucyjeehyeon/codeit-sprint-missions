# Sprint Mission 11. 자전거 대여 수요 예측

> 워싱턴 D.C. 자전거 대여 데이터를 탐색하고,
> EDA 결과를 기반으로 피처 엔지니어링과 머신러닝 모델링을 수행한 미션입니다.

---

## Project Summary

| 구분 | 내용 |
| --- | --- |
| 분석 주제 | 자전거 대여 패턴 분석 및 수요 예측 |
| 사용 도구 | Python, Pandas, scikit-learn |
| 예측 대상 | 시간대별 총 자전거 대여량 (`count`) |
| 평가 지표 | RMSLE |
| 주요 과정 | EDA, Feature Engineering, 모델 비교, Hyperparameter Tuning |
| 최종 모델 | Tuned RandomForest |
| 최종 RMSLE | 0.3264 |

---

## EDA Findings

- 자전거 대여량은 오전 8시와 오후 17~18시 전후에 크게 증가
- 근무일에는 출퇴근 시간대, 비근무일에는 낮 시간대 수요가 상대적으로 높음
- 맑고 따뜻한 날에 대여량이 증가하고, 습도가 높거나 날씨가 좋지 않을수록 감소
- 정기권 회원은 출퇴근 시간대, 비회원은 낮 시간대 이용 비중이 상대적으로 높음

EDA 결과를 통해 시간대, 근무일 여부, 기온, 습도, 날씨 등이
수요 예측에 중요한 변수임을 확인했습니다.

---

## Feature Engineering

EDA에서 확인한 패턴을 모델이 학습할 수 있도록 다음 파생변수를 생성했습니다.

- `hour`, `time_period`
- `rush_hour`, `is_commute_time`
- `is_weekend`
- `month`, `season_month`
- `temp_bin`, `humidity_bin`
- `windspeed_zero`

또한 오른쪽으로 치우친 `count` 분포를 고려해
`log1p(count)` target 변환도 실험했습니다.

---

## Model Performance

| Model | RMSLE |
| --- | ---: |
| Baseline LinearRegression | 1.1253 |
| Log LinearRegression | 0.6761 |
| DecisionTree | 0.4412 |
| GradientBoosting | 0.3874 |
| RandomForest | 0.3269 |
| **Tuned RandomForest** | **0.3264** |

비선형 관계와 변수 간 상호작용을 학습할 수 있는 RandomForest가 가장 좋은 성능을 보였으며,
하이퍼파라미터 튜닝 후 최종 RMSLE **0.3264**를 기록했습니다.

---

## Key Features

최종 모델의 주요 변수는 다음과 같습니다.

- `hour`
- `time_period_dawn`
- `temp`
- `is_commute_time`
- `workingday`

이는 EDA에서 확인한 시간대·출퇴근·근무일·기온 패턴과도 일치했습니다.

---

## Mentor Feedback

자전거 수요 문제의 특성을 반영한 다양한 파생변수 생성과
여러 모델 비교 후 RandomForest를 튜닝해 RMSLE 0.3264까지 개선한 점을 긍정적으로 평가받았습니다.

추가 개선 방향으로는 다음 내용을 제안받았습니다.

- 시계열 성격을 가진 데이터이므로 랜덤 분할 대신 시간 순서를 고려한 검증 방식 적용
- 하이퍼파라미터 선택에 사용한 validation set과 최종 성능 평가용 데이터를 분리하여 과대평가 가능성 방지

---

## Files

- [Analysis Notebook](./bike_demand_analysis.ipynb)
- [EDA Report](./bike_demand_eda_report.pdf)
- [Modeling Report](./bike_demand_modeling_report.pdf)
