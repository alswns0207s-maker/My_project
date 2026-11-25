#include <stdint.h>
#include <stdbool.h>

#define RCC_BASE   0x40023800UL
#define GPIOA_BASE 0x40020000UL
#define GPIOB_BASE 0x40020400UL
#define GPIOC_BASE 0x40020800UL
#define GPIOD_BASE 0x40020C00UL

#define REG(addr) (*(volatile uint32_t *)(addr))
#define RCC_AHB1ENR REG(RCC_BASE + 0x30UL)

typedef struct {
    volatile uint32_t MODER;    // +0x00
    volatile uint32_t OTYPER;   // +0x04
    volatile uint32_t OSPEEDR;  // +0x08
    volatile uint32_t PUPDR;    // +0x0C
    volatile uint32_t IDR;      // +0x10
    volatile uint32_t ODR;      // +0x14
    volatile uint32_t BSRR;     // +0x18
    volatile uint32_t LCKR;     // +0x1C
    volatile uint32_t AFRL;     // +0x20
    volatile uint32_t AFRH;     // +0x24
} gpio_regs_t;

typedef enum {
    GPIO_MODE_IN,
    GPIO_MODE_OUT,
    GPIO_MODE_AF,
    GPIO_MODE_ANALOGE
} gpio_mode_t;

typedef enum {
    GPIO_PULL_NONE,
    GPIO_PULL_UP,
    GPIO_PULL_DOWN
} gpio_pull_t;

void gpio_set_mode(gpio_regs_t *port, uint16_t pin,
                   gpio_mode_t mode)
{
    uint32_t v = port->MODER;
    v &= ~(3U << (pin * 2U));
    v |= ((uint32_t)mode << (pin * 2U));
    port->MODER = v;
}

void gpio_set_pull(gpio_regs_t *port, uint16_t pin,
                   gpio_pull_t pull)
{
    uint32_t v = port->PUPDR;
    v &= ~(3U << (pin * 2U));
    v |= ((uint32_t)pull << (pin * 2U)); // 수정: pin 기준 이동
    port->PUPDR = v;
}

void gpio_write(gpio_regs_t *port, uint16_t pin, bool level)
{
    port->BSRR = level ? (1U << pin)
                       : (1U << (pin + 16U));
}

bool gpio_read(const gpio_regs_t *port, uint16_t pin)
{
    return (port->IDR >> pin) & 1U;
}

void gpio_toggle(gpio_regs_t *port, uint16_t pin)
{
    uint32_t mask = 1U << pin;
    uint32_t odr = port->ODR;
    port->BSRR = ((odr & mask) << 16U) | (~odr & mask);
}

#define GPIOA ((gpio_regs_t *)GPIOA_BASE)
#define GPIOB ((gpio_regs_t *)GPIOB_BASE)
#define GPIOC ((gpio_regs_t *)GPIOC_BASE)
#define GPIOD ((gpio_regs_t *)GPIOD_BASE)

int main(void)
{
    // 반드시 GPIO 설정 전에 클럭 활성화
    RCC_AHB1ENR |= (1U << 0); // GPIOA
    RCC_AHB1ENR |= (1U << 2); // GPIOC
    (void)RCC_AHB1ENR;

    // PA5 초기 LOW, Push-pull
    gpio_write(GPIOA, 5, 0);
    GPIOA->OTYPER &= ~(1U << 5);

    gpio_set_mode(GPIOA, 5, GPIO_MODE_OUT);
    gpio_set_mode(GPIOC, 13, GPIO_MODE_IN);
    gpio_set_pull(GPIOC, 13, GPIO_PULL_UP);

    while (1)
    {
        if (gpio_read(GPIOC, 13) == 0)
        {
            gpio_write(GPIOA, 5, 1);
        }
        else
        {
            gpio_write(GPIOA, 5, 0);
        }
    }
}
