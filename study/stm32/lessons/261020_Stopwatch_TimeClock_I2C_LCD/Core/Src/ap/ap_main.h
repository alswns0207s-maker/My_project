#ifndef SRC_AP_AP_MAIN_H_
#define SRC_AP_AP_MAIN_H_
typedef enum {TIME_CLOCK_MODE, STOP_WATCH_MODE} app_mode_t;
app_mode_t ap_getMode(void);
int ap_main(void);
#endif
