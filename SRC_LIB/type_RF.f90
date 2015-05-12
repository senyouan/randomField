module type_RF

    use mpi
    use charFunctions

    implicit none

    type :: RF
        !MPI VARIABLES
        integer :: comm = -1
        integer :: rang = -1
        integer :: nb_procs = -1

        !GENERATION VARIABLES
            !nDim independent
        integer :: nDim = -1!, xNTotal = -1, kNTotal = -1;
        integer(kind=8) :: xNTotal = -1, kNTotal = -1;
        integer :: seedStart = -1
        character (len=15) :: corrMod = "Not", margiFirst = "Not";
        double precision   :: fieldAvg = -1, fieldVar = -1;
        integer            :: method = -1!1 for Isotropic, 2 for Shinozuka, 3 for Randomization
        integer            :: Nmc = -1
        logical :: init = .false.
        logical :: independent
            !nDim dependent
        double precision, dimension(:)   , allocatable :: corrL, kMax;
        double precision, dimension(:, :), allocatable :: kPoints;
        double precision, dimension(:)   , allocatable :: SkVec;
        double precision, dimension(:, :), allocatable :: xPoints_Local
        double precision, dimension(:, :), allocatable :: randField_Local
        integer, dimension(:), allocatable :: seed
        double precision, dimension(:), allocatable :: xMaxGlob, xMinGlob;
        double precision, dimension(:), allocatable :: xMaxBound, xMinBound;
        double precision, pointer :: xPoints(:,:)
        double precision, pointer :: randField(:,:)
        logical, dimension(:), allocatable :: calculate

    end type RF

    contains
        !---------------------------------------------------------------------------------
        !---------------------------------------------------------------------------------
        !---------------------------------------------------------------------------------
        !---------------------------------------------------------------------------------
        subroutine init_RF(RF_a, nDim, Nmc, comm, rang, nb_procs)
            type(RF) :: RF_a
            integer :: nDim, Nmc, comm, rang, nb_procs
            integer :: n

            RF_a%nDim     = nDim
            RF_a%Nmc      = Nmc
            RF_a%comm     = comm
            RF_a%rang     = rang
            RF_a%nb_procs = nb_procs
            allocate(RF_a%corrL(nDim))
            allocate(RF_a%kMax(nDim))
            allocate(RF_a%xMinGlob(nDim))
            allocate(RF_a%xMaxGlob(nDim))
            allocate(RF_a%calculate(Nmc))
            allocate(RF_a%xMaxBound(nDim))
            allocate(RF_a%xMinBound(nDim))
            call random_seed(size = n)
            allocate(RF_a%seed(n))
            RF_a%corrL = -1
            RF_a%kMax  = -1
            RF_a%seed  = -1
            RF_a%xMinGlob = -1
            RF_a%xMaxGlob = -1
            RF_a%xMinBound = -1
            RF_a%xMaxBound = -1
            RF_a%calculate(:) = .true.
            RF_a%init  = .true.

        end subroutine init_RF

        !---------------------------------------------------------------------------------
        !---------------------------------------------------------------------------------
        !---------------------------------------------------------------------------------
        !---------------------------------------------------------------------------------
        subroutine show_RF(RF_a, name, fmt, unit_in)
            !INPUT
            type(RF), intent(in) :: RF_a
            character(len=*), intent(in), optional :: name
            character(len = 20), intent(in), optional :: fmt
            integer, intent(in), optional :: unit_in
            !LOCAL
            character(len = 20) :: dblFmt
            integer :: unit

            dblFmt = "T25,F15.5"
            if(present(fmt)) dblFmt = fmt
            unit = 6 !Screen
            if(present(unit_in)) unit = unit_in

            write(unit,*) "RF--------------------------------------------------------------"
            if(present(name)) write(unit,*) "|  ", name

            if(RF_a%init) then
                write(unit,*) "|  init       = ", RF_a%init
                write(unit,*) "|"
                write(unit,*) "|  MPI---"
                write(unit,*) "|  |rang       = ", RF_a%rang
                write(unit,*) "|  |nb_procs   = ", RF_a%nb_procs
                write(unit,*) "|  |comm       = ", RF_a%comm
                write(unit,*) "|"
                write(unit,*) "|  Generation---"
                write(unit,*) "|  |nDim       = ", RF_a%nDim
                write(unit,*) "|  |independent= ", RF_a%independent
                write(unit,*) "|  |corrMod    = ", RF_a%corrMod
                write(unit,*) "|  |margiFirst = ", RF_a%margiFirst
                write(unit,*) "|  |method     = ", RF_a%method
                write(unit,*) "|  |Nmc        = ", RF_a%Nmc
                write(unit,"(A,("//dblFmt//"))") " |  |corrL      = ", RF_a%corrL
                write(unit,"(A,("//dblFmt//"))") " |  |fieldAvg   = ", RF_a%fieldAvg
                write(unit,"(A,("//dblFmt//"))") " |  |fieldVar   = ", RF_a%fieldVar
                write(unit,*) "|  |seedStart  = ", RF_a%seedStart
                write(unit,*) "|  |calculate  = ", RF_a%calculate
                write(unit,*) "|"
                write(unit,*) "|  Process--"
                write(unit,*) "|  |"
                write(unit,*) "|  |xPOINTS"
                write(unit,"(A,("//dblFmt//"))") " |  |  |xMinGlob   = ", RF_a%xMinGlob
                write(unit,"(A,("//dblFmt//"))") " |  |  |xMaxGlob   = ", RF_a%xMaxGlob
                write(unit,"(A,("//dblFmt//"))") " |  |  |xMinBound  = ", RF_a%xMinBound
                write(unit,"(A,("//dblFmt//"))") " |  |  |xMaxBound  = ", RF_a%xMaxBound
                write(unit,*) "|  |  |xNTotal                    = ", RF_a%xNTotal
                write(unit,*) "|  |  |associated(xPoints)        = ", associated(RF_a%xPoints)
                if(associated(RF_a%xPoints)) &
                write(unit,*) "|  |  |shape(xPoints)             = ", shape(RF_a%xPoints)
                write(unit,*) "|  |  |allocated(xPoints_Local)   = ", allocated(RF_a%xPoints_Local)
                if(allocated(RF_a%xPoints_Local)) &
                write(unit,*) "|  |  |shape(xPoints_Local)       = ", shape(RF_a%xPoints_Local)
                write(unit,*) "|  |"
                write(unit,*) "|  |kPOINTS"
                write(unit,"(A,("//dblFmt//"))") " |  |  |kMax       = ", RF_a%kMax
                write(unit,*) "|  |  |kNTotal                    = ", RF_a%kNTotal
                write(unit,*) "|  |  |allocated(kPoints)         = ", allocated(RF_a%kPoints)
                if(allocated(RF_a%kPoints)) &
                write(unit,*) "|  |  |shape(kPoints)             = ", shape(RF_a%kPoints)
                write(unit,*) "|  |  |allocated(SkVec)           = ", allocated(RF_a%SkVec)
                if(allocated(RF_a%SkVec)) &
                write(unit,*) "|  |  |shape(SkVec)               = ", shape(RF_a%SkVec)
                write(unit,*) "|  |"
                write(unit,*) "|  |RANDOM FIELD"
                write(unit,*) "|  |  |associated(randField)      = ", associated(RF_a%randField)
                if(associated(RF_a%randField)) &
                write(unit,*) "|  |  |shape(randField)           = ", shape(RF_a%randField)
                write(unit,*) "|  |  |allocated(randField_Local) = ", allocated(RF_a%randField_Local)
                if(allocated(RF_a%randField_Local)) &
                write(unit,*) "|  |  |shape(randField_Local)     = ", shape(RF_a%randField_Local)
                write(unit,*) "|  |"
                write(unit,*) "|  |SEED"
                write(unit,*) "|  |  |allocated(seed)            = ", allocated(RF_a%seed)
                if(allocated(RF_a%seed)) &
                write(unit,*) "|  |  |seed                       = ", RF_a%seed
                write(unit,*) "|"
            else
                write(unit,*) "|    init     = ", RF_a%init
                write(unit,*) "|RF has not been initialized----"
            end if
            write(unit,*) "|---------------------------------------------------------------"
            write(unit,*) ""

        end subroutine show_RF

        !---------------------------------------------------------------------------------
        !---------------------------------------------------------------------------------
        !---------------------------------------------------------------------------------
        !---------------------------------------------------------------------------------
        subroutine allocate_randField(RDF, randField)
            !INPUT AND OUTPUT
            type(RF)   :: RDF
            double precision, dimension(:,:), allocatable, target :: randField

            allocate(randField(RDF%xNTotal, RDF%Nmc))

            RDF%randField => randField

        end subroutine allocate_randField

        !---------------------------------------------------------------------------------
        !---------------------------------------------------------------------------------
        !---------------------------------------------------------------------------------
        !---------------------------------------------------------------------------------
        subroutine finalize_RF(RF_a)
            type(RF) :: RF_a

            RF_a%comm      = -1
            RF_a%rang      = -1
            RF_a%nb_procs  = -1
            RF_a%nDim      = -1
            RF_a%xNTotal   = -1
            RF_a%kNTotal   = -1
            RF_a%seedStart = -1
            RF_a%fieldAvg  = -1
            RF_a%fieldVar  = -1
            RF_a%Nmc       = -1
            RF_a%corrMod    = "Not"
            RF_a%margiFirst = "Not"
            RF_a%method     = "Not"
            if(allocated(RF_a%corrL))     deallocate(RF_a%corrL)
            if(allocated(RF_a%randField_Local)) deallocate(RF_a%randField_Local)
            if(allocated(RF_a%xPoints_Local))   deallocate(RF_a%xPoints_Local)
            if(allocated(RF_a%seed))      deallocate(RF_a%seed)
            if(allocated(RF_a%kMax))      deallocate(RF_a%kMax)
            if(allocated(RF_a%kPoints))   deallocate(RF_a%kPoints)
            if(allocated(RF_a%SkVec))     deallocate(RF_a%SkVec)
            if(allocated(RF_a%xMinGlob))  deallocate(RF_a%xMinGlob)
            if(allocated(RF_a%xMaxGlob))  deallocate(RF_a%xMaxGlob)
            if(allocated(RF_a%calculate)) deallocate(RF_a%calculate)
            if(allocated(RF_a%xMaxBound))   deallocate(RF_a%xMaxBound)
            if(allocated(RF_a%xMinBound))   deallocate(RF_a%xMinBound)
            if(associated(RF_a%xPoints))  nullify (RF_a%xPoints)
            if(associated(RF_a%randField))  nullify (RF_a%randField)
            RF_a%init = .false.

        end subroutine finalize_RF

end module type_RF
