# DHT11 온습도 SW 스택

- Application: Core/Src/ap/ap_main.c — 측정 결과를 LCD와 UART로 출력
- Service: Core/Src/service/temp_humid_service.c — 약 2초마다 측정 요청
- Driver: Core/Src/driver/DHT11/dht11.c — DHT11 통신 및 체크섬 검사
- HAL: HAL_GPIO_ReadPin / HAL_GPIO_WritePin / HAL_GPIO_Init
- LCD Driver: Core/Src/driver/lcd/lcd.c — I2C LCD 출력

main()은 ap_init()을 한 번 실행하고, 반복문에서 ap_main()을 호출합니다.
서비스 Task는 일반 C 함수이며 RTOS를 사용하지 않습니다.
센서 전원 안정화 2초 후 첫 측정, 이후 측정 완료부터 2초 뒤 다음 측정입니다.

배선 설정: DHT11 DATA=PC8, LCD SCL=PB8, SDA=PB9, I2C 주소=0x27.
LCD는 PCF8574 방식 16x2 모듈 기준입니다.
LCD 첫 줄에는 온도, 둘째 줄에는 습도를 표시하며 UART2(115200)에도 출력합니다.
센서 읽기 실패 시 LCD에 DHT11 error를 표시하고 다음 주기에 다시 시도합니다.

CubeIDE에서 프로젝트를 선택하고 F5로 새 파일을 반영한 뒤 Build/Run 하세요.
전체 컴파일 및 링크 확인 완료. 실제 보드 다운로드와 LCD 표시는 확인하지 않았습니다.
