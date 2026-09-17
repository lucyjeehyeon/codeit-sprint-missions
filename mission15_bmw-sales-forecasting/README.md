# Sprint Mission 15. BMW 글로벌 판매 시계열 분석 및 예측

> BMW 그룹의 글로벌 판매 데이터를 기반으로 시계열 패턴을 분석하고,
> 다양한 예측 모델과 bottom-up 접근을 비교해 최종 판매 예측 모델을 선정한 미션입니다.

---

## Project Summary

| 구분 | 내용 |
| --- | --- |
| 분석 주제 | BMW 글로벌 월별 판매량 시계열 분석 및 예측 |
| 분석 기간 | 2018.01 ~ 2025.12 |
| 사용 도구 | Python, Pandas, statsmodels, Prophet |
| 주요 기법 | STL, ACF, ARIMA, SARIMA, Holt-Winters, Prophet |
| 평가 지표 | MAE |
| 최종 운영안 | Model bottom-up |
| 최종 MAE | 16,437 |
| 최종 WAPE | 5.87% |

---

## Validation Design

시간 순서를 가진 데이터이므로 무작위 분할을 사용하지 않고 다음과 같이 검증 구간을 분리했습니다.

- **2018.01 ~ 2023.12**: 내부 학습
- **2024.01 ~ 2024.12**: 모델 및 하이퍼파라미터 선택
- **2018.01 ~ 2024.12**: 선택 모델 재학습
- **2025.01 ~ 2025.12**: 최종 홀드아웃 평가

최종 테스트 기간을 모델 선택에 재사용하지 않아
예측 성능의 과대평가 가능성을 줄였습니다.

---

## Time Series Analysis

월별 데이터의 계절 주기를 단순히 12개월로 가정하지 않고
ACF와 주파수 분석을 통해 반복 패턴을 확인했습니다.

- 3개월 lag ACF: **0.595**
- 6개월 lag ACF: 0.491
- 12개월 lag ACF: 0.409

분석 결과 가장 강한 반복은 **3개월 주기**로 나타났고,
STL과 SARIMA의 계절 주기로 `s=3`을 우선 적용했습니다.

---

## Model Comparison

다음 모델을 비교했습니다.

- Naive
- Seasonal Naive
- Simple Exponential Smoothing
- Holt / Holt-Winters
- ARIMA
- SARIMA
- Prophet

### Direct Total Forecast

| Model | MAE |
| --- | ---: |
| ARIMA(3,1,3) | **17,762** |
| Prophet | 20,198 |
| Holt-Winters | 21,015 |
| Seasonal Naive (12) | 21,113 |
| Seasonal Naive (3) | 23,846 |
| SARIMA | 44,307 |
| Naive | 48,075 |

직접 총량 예측에서는 **ARIMA(3,1,3)**이 가장 안정적인 성능을 보였습니다.

---

## Bottom-up Forecasting

전체 판매량을 직접 예측하는 방식과
지역별·차종별 예측을 합산하는 bottom-up 방식을 비교했습니다.

| Approach | MAE | WAPE |
| --- | ---: | ---: |
| **Model bottom-up** | **16,437** | **5.87%** |
| Region bottom-up | 17,265 | 6.16% |
| Direct total ARIMA | 17,762 | 6.34% |

차종별 bottom-up 방식이 최종 챔피언으로 선정되었습니다.

개별 차종 예측의 오차가 모두 작았던 것은 아니지만,
합산 과정에서 과대·과소 예측이 일부 상쇄되면서
전체 판매량 예측 성능이 개선되었습니다.

---

## 2026 Forecast

최종 model bottom-up 기준 2026년 예상 판매량은

**3,292,356대**

로 나타났으며,
2025년 대비 약 **-2.1%** 수준입니다.

또한 3·6·9·12월에 상대적으로 높은 판매가 나타나는
분기 말 패턴이 유지되는 것으로 예측했습니다.

---

## Key Insights

- 월별 데이터라고 해서 계절 주기를 무조건 12개월로 두는 것은 적절하지 않음
- 이번 데이터에서는 분기 말 효과에 가까운 3개월 반복이 가장 강하게 확인됨
- 복잡한 SARIMA가 항상 단순 ARIMA보다 좋은 성능을 보이지 않음
- 실제 미래 예측에서는 시간 순서를 유지한 검증 구조가 중요함
- 전체 판매량 계획에는 차종별 bottom-up 방식이 더 효과적이었음

---

## Limitations

- 실제 BMW 공식 판매 데이터가 아닌 교육용 재구성 데이터
- 전체 기간이 96개월로 복잡한 계절모형 검증에는 다소 짧음
- 코로나 시기 및 공급 제약과 같은 구조적 이벤트 변수가 없음
- 미래 GDP·유가·가격·프로모션 계획이 없어 외생변수를 본선 모델에 사용하지 않음
- bottom-up의 총량 개선에는 차종 간 예측 오차 상쇄 효과가 포함됨

---

## Files

- [Analysis Notebook](./bmw_sales_forecasting.ipynb)
- [Analysis Report](./bmw_sales_forecasting_report.pdf)
