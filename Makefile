ARCHS = armv7 armv7s
TARGET = iphone:clang:latest:5.0

include theos/makefiles/common.mk

TWEAK_NAME = SevenCenter
SevenCenter_FILES = Tweak.xm
SevenCenter_CFLAGS = -fobjc-arc
SevenCenter_FRAMEWORKS = Foundation UIKit CoreGraphics Accelerate

include $(THEOS_MAKE_PATH)/tweak.mk