# v0.5 → v0.6 업데이트

이 버전은 이전에 전달한 v0.5 파일을 바탕으로 수정했습니다
GitHub에서 친구가 추가한 최신 이벤트/코드는 읽거나 병합하지 않았습니다
친구 작업이 있다면 전체 프로젝트를 덮어쓰지 말고 업데이트 브랜치에서 아래 변경 파일만 적용하세요
먼저 기존 변경을 Commit하고 최신 main을 Pull한 뒤 브랜치를 만드세요
기존 수정과 겹치는 .gd/.tscn은 변경 내용을 비교해서 병합하세요

## 변경 파일

scripts/game.gd: 자동문 센서, 지연/유지/안전 재열림, 모터음, 미닫이 이동
scripts/world_builder.gd: 양쪽 패널 자동문, 하늘 반사 환경
scripts/player.gd: 달리기 상하/좌우 흔들림과 카메라 롤
scripts/movement_tuning.gd: 추가 속도/흔들림 설정 필드
scripts/cctv.gd: 이전 협업판과 동일
visuals/player/MovementTuning.tres: 걷기 2.8m/s, 달리기 5m/s, run_bob/run_roll
visuals/player/PlayerBody.tscn, LeftHand.tscn, RightHand.tscn: 박스 대신 둥근 체형
visuals/customer/CustomerVisual.tscn: 둥근 몸통/사지, 어깨/목/손/신발 추가 (사진 얼굴 유지)
visuals/environment/EnvironmentVisual.tscn: 유리 재질 연결
visuals/environment/Glass.tres: 새 반사 유리 재질
assets/door_motor.wav 및 assets/door_motor.wav.import: 새 모터음
 tests/smoke.gd: 49개 검사

## 설정

자동문 감지 지연 0.45초 / 센서 비운 후 유지 3초 / 움직임 1.1초
문 닫는 도중 재진입하면 즉시 다시 열림, 센서 영역에 있는 동안 열린 상태 유지
양쪽 출입 방향에서 플레이어/현재 손님 감지
센서는 현재 손님 1명 시스템에 연결됨. 친구가 NPC를 더 만들면 감지 대상에 추가 필요
달리기 흔들림은 MovementTuning.tres에서 조절, B키로 끄기 가능
유리 반사는 하늘/조명 기반이며 실시간으로 모든 주변 물체를 비추는 거울은 아님
캐릭터는 간단한 둥근 인체 형태이며 전문적인 실사 리깅 모델은 아님
41개 기존 검사 + 8개 신규 검사 통과, 실제 화면은 미검증
