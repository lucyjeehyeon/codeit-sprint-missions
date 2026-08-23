# Sprint Mission 12. 정기예금 가입 예측

> 포르투갈 은행의 마케팅 캠페인 데이터를 분석하고,
> 불균형 데이터에서 정기예금 가입 가능성을 예측하는 분류 모델을 개발한 미션입니다.

---

## Project Summary

| 구분 | 내용 |
| --- | --- |
| 분석 주제 | 정기예금 가입 패턴 분석 및 가입 여부 예측 |
| 사용 도구 | Python, Pandas, scikit-learn, LightGBM |
| 예측 대상 | 정기예금 가입 여부 (`y`) |
| 데이터 특징 | 가입자 약 11.7%의 클래스 불균형 |
| 평가 지표 | Accuracy, Precision, Recall, F1-score |
| 최종 모델 | LightGBM + Class Weight + Threshold |
| 최종 Accuracy | 0.8824 |
| 가입자 F1-score | 0.4838 |

---

## EDA Findings

- 이전 캠페인 성공 고객의 가입률이 약 64.7%로 가장 강한 가입 신호
- 이전 연락 이력이 있는 고객의 가입률이 그렇지 않은 고객보다 높음
- 잔고가 높고 대출 부담이 낮은 고객일수록 가입률이 높음
- 고령층과 학생·은퇴자 그룹에서 상대적으로 높은 가입률 확인
- 현재 캠페인의 연락 횟수가 많아질수록 가입률은 낮아지는 경향
- 연락 수단이 `unknown`인 고객의 가입률은 상대적으로 낮음

이를 바탕으로 고객의 금융 상태, 생애단계, 현재 캠페인,
이전 캠페인 이력을 주요 모델링 변수로 활용했습니다.

---

## Modeling

클래스 불균형으로 인해 Accuracy만으로 모델을 평가하지 않고
가입자 클래스의 Precision, Recall, F1-score를 함께 비교했습니다.

다음 방법을 순차적으로 적용했습니다.

- Logistic Regression 기준 모델 구축
- `class_weight` 및 `sample_weight`
- SMOTE
- Random Forest, Extra Trees
- Gradient Boosting
- XGBoost, LightGBM, CatBoost
- Validation set 기반 Threshold 튜닝

---

## Final Model

최종 모델은 LightGBM에 다음 설정을 적용했습니다.

- `class_weight = {0: 1, 1: 2.5}`
- `threshold = 0.47`

| Metric | Score |
| --- | ---: |
| Accuracy | 0.8824 |
| 가입자 Precision | 0.4977 |
| 가입자 Recall | 0.4707 |
| **가입자 F1-score** | **0.4838** |
| Macro F1 | 0.7087 |

심화 목표였던 **Accuracy 0.88 이상**,  
**가입자 F1-score 0.45 이상**을 모두 충족했습니다.

---

## Key Features

최종 모델에서 중요도가 높게 나타난 주요 변수는 다음과 같습니다.

- `balance`
- `age`
- `day`
- `campaign`
- `month`
- `pdays`
- `job`

---

## Mentor Feedback

클래스 불균형을 인식하고 Accuracy 외의 여러 성능 지표를 함께 평가한 점과,
다양한 모델 비교 후 validation set에서 threshold를 조정해
LightGBM을 최종 모델로 선정한 과정을 긍정적으로 평가받았습니다.

다만 `pdays`, `pdays_clean`, `pdays_for_model`처럼
같은 정보를 표현하는 변수가 중복 사용되고 있어,
향후에는 중복 피처를 정리해 모델 입력 변수를 더 명확하게 구성할 필요가 있습니다.

---

## Files

- [Analysis Notebook](./bank_deposit_prediction.ipynb)
- [EDA Report](./bank_deposit_eda_report.pdf)
- [Modeling Report](./bank_deposit_modeling_report.pdf)
