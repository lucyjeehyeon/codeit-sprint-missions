# Sprint Mission 14. SNS 텍스트 감정 분석 및 분류

> SNS 텍스트를 전처리해 감정별 특징 단어를 분석하고,
> TF-IDF 기반 머신러닝 모델로 여섯 가지 감정을 분류한 미션입니다.

---

## Project Summary

| 구분 | 내용 |
| --- | --- |
| 분석 주제 | SNS 텍스트 감정 분석 및 분류 |
| 사용 도구 | Python, Pandas, scikit-learn |
| 감정 클래스 | sadness, joy, love, anger, fear, surprise |
| 주요 분석 | 텍스트 전처리, 워드클라우드, TF-IDF, 분류 모델 비교 |
| 최종 모델 | Word + Character TF-IDF + Linear SVM |
| 6-class Accuracy | 0.897 |
| 6-class Macro F1 | 0.856 |
| Binary Accuracy | 0.978 |

---

## Text Preprocessing

분류용 전처리와 시각화용 전처리를 분리했습니다.

### Classification
- 소문자화
- URL 및 사용자명 치환
- 해시태그 기호 제거 후 단어 보존
- 불필요한 문장부호 제거
- 연속 공백 정리

불용어와 품사 제한은 감정 문맥을 잃을 수 있어 분류 입력에는 적용하지 않았습니다.

### Word Cloud
- 명사·동사·형용사·부사만 유지
- Lemmatization
- 일반 불용어 제거
- `feel`, `feeling`, `really`, `like` 등 공통 표현 제거
- chi-square와 log-lift를 활용해 감정별 특징 단어 강조

---

## Emotion Keywords

감정별로 다른 감정과 구분되는 대표 단어를 확인했습니다.

- **sadness** → gloomy, inadequate, melancholy
- **joy** → festive, energetic, superior
- **love** → sympathetic, loyal, tender
- **anger** → resentful, greedy, irritable
- **fear** → apprehensive, vulnerable, shaky
- **surprise** → curious, impressed, amazed

---

## Model Comparison

학습 데이터 내부의 Stratified 3-fold 교차검증으로 모델을 비교했습니다.

| Model | CV Macro F1 |
| --- | ---: |
| Hybrid Word + Char TF-IDF + Linear SVM | **0.863** |
| Word TF-IDF + Linear SVM | 0.856 |
| Count Vectorizer + Logistic Regression | 0.855 |
| Word TF-IDF + Logistic Regression | 0.846 |
| Character TF-IDF + Linear SVM | 0.841 |
| Complement Naive Bayes | 0.834 |
| POS content words + Linear SVM | 0.822 |

단어 TF-IDF는 의미 정보를,
문자 TF-IDF는 축약·철자 변형을 보완해 두 표현을 결합한 모델이 가장 좋은 성능을 보였습니다.

---

## Final Performance

| Metric | Score |
| --- | ---: |
| Accuracy | 0.897 |
| Macro F1 | 0.856 |
| Weighted F1 | 0.898 |

감정별 F1은 sadness와 joy에서 가장 높았으며,
표본이 적은 love와 surprise는 상대적으로 분류 난도가 높았습니다.

---

## Binary Classification

joy·love를 긍정,
sadness·anger·fear를 부정으로 통합하고 surprise를 제외해 이진 분류도 수행했습니다.

| Task | Accuracy | Macro F1 |
| --- | ---: | ---: |
| 6-class | 0.897 | 0.856 |
| Binary | **0.978** | **0.978** |

이진 분류의 ROC-AUC는 **0.997**을 기록했습니다.

---

## Limitations

- 하나의 문장에 하나의 감정 라벨만 존재해 혼합 감정을 표현하지 못함
- surprise는 긍정·부정 의미가 혼재할 수 있음
- 풍자·맥락·화자 관계를 n-gram만으로 완전히 해석하기 어려움
- 다른 플랫폼이나 시기에 적용할 경우 도메인 drift 검증 필요

---

## Files

- [Analysis Notebook](./text_emotion_classification.ipynb)
- [Analysis Report](./text_emotion_analysis_report.pdf)
