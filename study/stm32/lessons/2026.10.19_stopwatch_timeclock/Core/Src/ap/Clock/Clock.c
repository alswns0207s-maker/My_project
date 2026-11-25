#include "Clock.h"

/* PDF's clock display is minutes/seconds, wrapping after 59:59. */


static TimeClock_t timeClockData;

void Timeclock_init(void){
    timeclockdata.hour = 0;
    timeclockdata.min = 0;
    timeclockdata.sec = 0;
    timeclockdata.msec = 0;

}

void TimeClock_incmsec(void)
{
    if(timeClockData.msec < 99){
        timeClockData.msec++;
        return;
    }
    timeClockData.msec = 0;
    if(timeClockData.sec < 59){
        timeClockData.sec++;
        return;
    }
    timeClockData.sec = 0;
    if(timeClockData.min < 59){
        timeClockData.min++;
        return;
    }
    timeClockData.min = 0;
    if(timeClockData.hour < 23){
        timeClockData.hour++;
        return;
    }
    timeClockData.hour = 0;
}

void timeclock_disptime(void){
    uint16_t num;
    num = (timeClockData.min*100) + timeClockData.sec;
    fnd_set_num(num);
    if(timeclockdata.msec<50){
        fnd_set_dp(FND_DIGIT_2, FND_DP_ON);
    }
    else fnd_set_dp(FND_DIGIT_2, FND_DP_OFF);
}

void Timeclock_ISR(void){
    TimeClock_incmsec();
}

void TimeClock_task(void){
    timeclock_disptime();
}
