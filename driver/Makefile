# ============================================================================
# Makefile for Ara MultiCore WSE Linux Kernel Module
# Supports paths with spaces and auto-detects LLVM/Clang kernel toolchains.
# ============================================================================

obj-m += ara_wse.o
ara_wse-objs := ara_wse_driver.o

KDIR ?= /lib/modules/$(shell uname -r)/build
CUR_DIR := $(shell pwd)
LLVM_OPT := $(shell grep -q "clang" $(KDIR)/include/generated/compile.h 2>/dev/null && echo "LLVM=1 CC=clang" || which clang >/dev/null 2>&1 && echo "LLVM=1 CC=clang" || echo "")

default:
	@if echo "$(CUR_DIR)" | grep -q " "; then \
		echo "Path contains spaces. Staging build in /tmp/ara_wse_kbuild..."; \
		mkdir -p /tmp/ara_wse_kbuild; \
		cp -f $(CUR_DIR)/ara_wse_driver.[ch] $(CUR_DIR)/Makefile /tmp/ara_wse_kbuild/; \
		$(MAKE) -C $(KDIR) M=/tmp/ara_wse_kbuild $(LLVM_OPT) modules; \
		cp -f /tmp/ara_wse_kbuild/ara_wse.ko $(CUR_DIR)/ 2>/dev/null || true; \
		echo "Build complete: ara_wse.ko staged to $(CUR_DIR)"; \
	else \
		$(MAKE) -C $(KDIR) M=$(CUR_DIR) $(LLVM_OPT) modules; \
	fi

clean:
	@if [ -d /tmp/ara_wse_kbuild ]; then \
		$(MAKE) -C $(KDIR) M=/tmp/ara_wse_kbuild clean 2>/dev/null || true; \
		rm -rf /tmp/ara_wse_kbuild; \
	fi
	rm -f *.o *.ko *.mod *.mod.c *.order *.symvers .*.cmd
