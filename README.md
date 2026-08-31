# LeNet-5 FPGA AI Accelerator — C5 Layer · Weight BRAM Controller · Classifier

> RTL blocks I designed for a LeNet-5 inference accelerator on AWS FPGA — 75 MACs/cycle mapped 1:1 to DSP slices, 4-stage pipeline, 140MHz timing closure. Grand Prize (최우수상), 2nd AI Semiconductor Talent Competition, Dec 2025.

## 프로젝트 개요
제2회 AI 반도체 기술인재 선발대회(팀 4인) 출품작 — AWS FPGA 환경에서 LeNet-5 추론 가속기를 구현해 MNIST 판정 이미지 10장의 정확도와 처리 성능을 겨루는 대회였습니다. 팀 결과: **판정 이미지 10장 전수 일치, SW 대비 5.13배 가속, 최우수상(정보통신산업진흥원장상, 2025.12)**.

## 본인 역할 (이 저장소의 범위)
팀 4인 중 곱셈량이 가장 많은 구간을 담당했습니다. 이 저장소는 **본인이 설계·검증·합성·구현한 블록만** 담고 있습니다. 전체 통합 구조(타 레이어·시스템 top·통합 테스트벤치)는 팀 공동 산출물이라 포함하지 않았습니다.

| 파일 | 블록 | 설명 |
|---|---|---|
| `src/c5_conv.v` | C5 Convolution Layer | 클럭당 75개 MAC을 DSP slice에 일대일 매핑, 덧셈 트리를 4-Stage Pipeline으로 분할(p1 병렬 MAC → p2~p3 부분합·채널합 → p4 누적)해 Critical Path 최적화 |
| `src/c5_bram_controller.v` | 가중치 공급 BRAM 컨트롤러 | C5 연산에 맞춰 가중치를 공급 — 라인버퍼 valid 신호 기반 Pre-fetching으로 연산 유닛 유휴 최소화 |
| `src/max_value_parallel.v` | 최종 분류 Comparator | 10개 로짓에서 최댓값 인덱스를 병렬 비교로 산출 (Stream 방식 대비 지연 우위로 Parallel 채택) |
| `src/jby_top.v` | 담당 블록 통합 top | c5_conv + c5_bram_controller 연결 래퍼 |

## 핵심 결과
- **140MHz Timing Closure** — 합성 후 Timing Violation을 Critical Path 분석으로 해결
- 시뮬레이션 불일치 디버깅: 기대값 수계산·파형 단계별 대조·입력 파일 바이트 단위 대조로 원인을 입력 데이터 순서 문제로 특정
- 판정 이미지 10장 전수 일치 · SW 대비 5.13배 가속 (팀 통합 결과)

## 참고
- 가중치 hex·메모리 프리미티브·통합 시뮬레이션 환경은 팀 공동 자산이라 미포함 — 모듈 인터페이스는 각 파일의 포트 선언 참조.
- 환경: Verilog HDL, Xilinx Vivado (합성·구현·타이밍 분석), AWS FPGA

## Environment
Verilog HDL · Xilinx Vivado · AWS F1 FPGA
