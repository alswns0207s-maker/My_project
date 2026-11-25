
#include "xparameters.h"
#include "xil_io.h"
#include "xil_printf.h"
#include "sleep.h"

#define GPIO_BASE XPAR_GPIO_AXI_IP_0_S00_AXI_BASEADDR
#define GPIO_CONTROL_OFFSET 0x00U
#define GPIO_DATA_OFFSET    0x04U

int main(void)
{
    unsigned int led = 0;

    /* CR bit 1 enables output; ODR holds the LED value. */
    Xil_Out32(GPIO_BASE + GPIO_DATA_OFFSET, 0U);
    Xil_Out32(GPIO_BASE + GPIO_CONTROL_OFFSET, 0x0FU);

    xil_printf("AXI GPIO LED TEST\r\n");

    while (1)
    {
        Xil_Out32(GPIO_BASE + GPIO_DATA_OFFSET,
                  1U << led);

        xil_printf("LED %d ON\r\n", led);

        usleep(500000);

        led = (led + 1) % 4;
    }

    return 0;
}

