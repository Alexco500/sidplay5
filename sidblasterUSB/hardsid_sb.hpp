#ifndef _Included_HardSID
#define _Included_HardSID
#ifdef __cplusplus
extern "C" {
#endif

enum {  HSID_USB_WSTATE_OK = 1, HSID_USB_WSTATE_BUSY, HSID_USB_WSTATE_ERROR, HSID_USB_WSTATE_END};

typedef unsigned char Uint8;
typedef unsigned short Uint16;
typedef unsigned char boolean;

// fix by me
void  HardSID_Initialize();

void HardSID_Uninitialize();

Uint8 HardSID_Read(Uint8 DeviceID, int Cycles, Uint8 SID_reg);

Uint16 HardSID_Version(void);

Uint8 HardSID_Devices(void);

void HardSID_Delay(Uint8 DeviceID, Uint16 Cycles);

void HardSID_Write(Uint8 DeviceID, int Cycles, Uint8 SID_reg, Uint8 Data);

Uint8 HardSID_Read(Uint8 DeviceID, int Cycles, Uint8 SID_reg);

void HardSID_Flush(Uint8 DeviceID);

void HardSID_SoftFlush(Uint8 DeviceID);

boolean HardSID_Lock(Uint8 DeviceID);

void HardSID_Filter(Uint8 DeviceID, boolean Filter);

void HardSID_Reset(Uint8 DeviceID);

void HardSID_Sync(Uint8 DeviceID);

void HardSID_Mute(Uint8 DeviceID, Uint8 Channel, boolean Mute);

void HardSID_MuteAll(Uint8 DeviceID, boolean Mute);

void InitHardSID_Mapper(void);

Uint8 GetHardSIDCount(void);

void WriteToHardSID(Uint8 DeviceID, Uint8 SID_reg, Uint8 Data);

Uint8 ReadFromHardSID(Uint8 DeviceID, Uint8 SID_reg);

void MuteHardSID_Line(int Mute);

void HardSID_Reset2(Uint8 DeviceID, Uint8 Volume);

void HardSID_Unlock(Uint8 DeviceID);

// DLLs version 0x0301 and above
Uint8 HardSID_Try_Write(Uint8 DeviceID, int Cycles, Uint8 SID_reg, Uint8 Data);

boolean HardSID_ExternalTiming(Uint8 DeviceID);

// 0x202
void HardSID_GetSerial(char* output, int bufferSize, Uint8 DeviceID);

// 0x203
void HardSID_SetWriteBufferSize(Uint8 bufferSize);

void HardSID_SetWriteBufferSize(Uint8 bufferSize);

int HardSID_SetSIDType(Uint8 DeviceID, int sidtype_);

int HardSID_GetSIDType(Uint8 DeviceID);

int HardSID_SetSerial(Uint8 DeviceID, const char *SerialNo);

#ifdef __cplusplus
}
#endif
#endif
