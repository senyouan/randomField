module write_Log_File

    use charFunctions

    implicit none
    integer, save :: log_file_RF_ID

    interface wLog
        module procedure wLogString
        module procedure wLogLongInt
        module procedure wLogInt
        module procedure wLogDouble
        module procedure wLogBool
        module procedure wLogString_Vec
        module procedure wLogInt_Vec
        module procedure wLogDouble_Vec
        module procedure wLogBool_Vec
        module procedure wLogString_Arr
        module procedure wLogInt_Arr
        module procedure wLogDouble_Arr
        module procedure wLogBool_Arr
    end interface wLog

contains

    !-----------------------------------------------------------------------------------------------
    !-----------------------------------------------------------------------------------------------
    !-----------------------------------------------------------------------------------------------
    !-----------------------------------------------------------------------------------------------
    subroutine init_log_file(filename, rang, log_ID)
        implicit none
        !INPUT
        character(len=*), intent(in) :: filename
        integer         , intent(in) :: rang
        !OUTPUT
        integer         , intent(out) :: log_ID
        !LOCAL
        integer :: fileId
        integer :: cte = 100001
        character(len=300) :: fullName

        fullName = stringNumb_join(filename, rang)

        fileId = cte+rang
        log_file_RF_ID = fileId
        log_ID = fileId

        open (unit=fileId , file=fullName, action='write')

    end subroutine init_log_file

    !-----------------------------------------------------------------------------------------------
    !-----------------------------------------------------------------------------------------------
    !-----------------------------------------------------------------------------------------------
    !-----------------------------------------------------------------------------------------------
    subroutine finalize_log_file()
        implicit none

        close(log_file_RF_ID)

    end subroutine finalize_log_file

    !-----------------------------------------------------------------------------------------------
    !-----------------------------------------------------------------------------------------------
    !-----------------------------------------------------------------------------------------------
    !-----------------------------------------------------------------------------------------------
    subroutine wLogString(string)
        character(len=*), intent(in) :: string
        !write(*,*) "log_file_RF_ID inside STRING = ", log_file_RF_ID
#ifdef MAKELOG
        write(log_file_RF_ID,*) string
#endif
    end subroutine wLogString

    !-----------------------------------------------------------------------------------------------
    !-----------------------------------------------------------------------------------------------
    !-----------------------------------------------------------------------------------------------
    !-----------------------------------------------------------------------------------------------
    subroutine wLogInt(number)
        integer, intent(in) :: number
#ifdef MAKELOG
        write(log_file_RF_ID,*) number
#endif
    end subroutine wLogInt

    !-----------------------------------------------------------------------------------------------
    !-----------------------------------------------------------------------------------------------
    !-----------------------------------------------------------------------------------------------
    !-----------------------------------------------------------------------------------------------
    subroutine wLogLongInt(number)
        integer (kind=8), intent(in) :: number
#ifdef MAKELOG
        write(log_file_RF_ID,*) number
#endif
    end subroutine wLogLongInt

    !-----------------------------------------------------------------------------------------------
    !-----------------------------------------------------------------------------------------------
    !-----------------------------------------------------------------------------------------------
    !-----------------------------------------------------------------------------------------------
    subroutine wLogDouble(number)
        double precision, intent(in) :: number
#ifdef MAKELOG
        write(log_file_RF_ID,*) number
#endif
    end subroutine wLogDouble

    !-----------------------------------------------------------------------------------------------
    !-----------------------------------------------------------------------------------------------
    !-----------------------------------------------------------------------------------------------
    !-----------------------------------------------------------------------------------------------
    subroutine wLogBool(logic)
        logical, intent(in) :: logic
#ifdef MAKELOG
        write(log_file_RF_ID,*) logic
#endif
    end subroutine wLogBool

    !-----------------------------------------------------------------------------------------------
    !-----------------------------------------------------------------------------------------------
    !-----------------------------------------------------------------------------------------------
    !-----------------------------------------------------------------------------------------------
    subroutine wLogString_Vec(string)
        character(len=*), dimension(:), intent(in) :: string
#ifdef MAKELOG
        write(log_file_RF_ID,*) string
#endif
    end subroutine wLogString_Vec

    !-----------------------------------------------------------------------------------------------
    !-----------------------------------------------------------------------------------------------
    !-----------------------------------------------------------------------------------------------
    !-----------------------------------------------------------------------------------------------
    subroutine wLogInt_Vec(number)
        integer, dimension(:), intent(in) :: number
#ifdef MAKELOG
        write(log_file_RF_ID,*) number
#endif
    end subroutine wLogInt_Vec

    !-----------------------------------------------------------------------------------------------
    !-----------------------------------------------------------------------------------------------
    !-----------------------------------------------------------------------------------------------
    !-----------------------------------------------------------------------------------------------
    subroutine wLogDouble_Vec(number)
        double precision, dimension(:), intent(in) :: number
#ifdef MAKELOG
        write(log_file_RF_ID,*) number
#endif
    end subroutine wLogDouble_Vec

    !-----------------------------------------------------------------------------------------------
    !-----------------------------------------------------------------------------------------------
    !-----------------------------------------------------------------------------------------------
    !-----------------------------------------------------------------------------------------------
    subroutine wLogBool_Vec(logic)
        logical, dimension(:), intent(in) :: logic
#ifdef MAKELOG
        write(log_file_RF_ID,*) logic
#endif
    end subroutine wLogBool_Vec

    !-----------------------------------------------------------------------------------------------
    !-----------------------------------------------------------------------------------------------
    !-----------------------------------------------------------------------------------------------
    !-----------------------------------------------------------------------------------------------
    subroutine wLogString_Arr(string)
        character(len=*), dimension(:,:), intent(in) :: string
#ifdef MAKELOG
        write(log_file_RF_ID,*) string
#endif
    end subroutine wLogString_Arr

    !-----------------------------------------------------------------------------------------------
    !-----------------------------------------------------------------------------------------------
    !-----------------------------------------------------------------------------------------------
    !-----------------------------------------------------------------------------------------------
    subroutine wLogInt_Arr(number)
        integer, dimension(:,:), intent(in) :: number
#ifdef MAKELOG
        write(log_file_RF_ID,*) number
#endif
    end subroutine wLogInt_Arr

    !-----------------------------------------------------------------------------------------------
    !-----------------------------------------------------------------------------------------------
    !-----------------------------------------------------------------------------------------------
    !-----------------------------------------------------------------------------------------------
    subroutine wLogDouble_Arr(number)
        double precision, dimension(:,:), intent(in) :: number
#ifdef MAKELOG
        write(log_file_RF_ID,*) number
#endif
    end subroutine wLogDouble_Arr

    !-----------------------------------------------------------------------------------------------
    !-----------------------------------------------------------------------------------------------
    !-----------------------------------------------------------------------------------------------
    !-----------------------------------------------------------------------------------------------
    subroutine wLogBool_Arr(logic)
        logical, dimension(:,:), intent(in) :: logic
#ifdef MAKELOG
        write(log_file_RF_ID,*) logic
#endif
    end subroutine wLogBool_Arr


end module write_Log_File
