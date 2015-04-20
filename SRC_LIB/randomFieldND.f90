module randomFieldND

    use displayCarvalhol
    use spectra_RF
    use math_RF
    use constants_RF
    use mesh_RF
    use mpi
    use write_Log_File
    use type_RF

    implicit none
    !use blas

    interface createRandomField
       module procedure create_RF_Unstruct_noInit,   &
                        create_RF_Unstruct_Init
    end interface createRandomField



contains
    !-----------------------------------------------------------------------------------------------
    !-----------------------------------------------------------------------------------------------
    !-----------------------------------------------------------------------------------------------
    !-----------------------------------------------------------------------------------------------
    subroutine create_RF_Unstruct_noInit (xPoints, corrL, corrMod, Nmc,   &
                                          randField, method, seedStart,   &
                                          margiFirst, fieldAvg, fieldVar, &
                                          comm, rang, nb_procs, calculate)
        !INPUT
        double precision, dimension(1:, 1:), intent(in), target :: xPoints;
        double precision, dimension(1:)    , intent(in) :: corrL;
        character (len=*)                  , intent(in) :: corrMod;
        integer                            , intent(in) :: Nmc;
        integer                            , intent(in) :: method
        integer                            , intent(in) :: seedStart
        character (len=*)                  , intent(in) :: margiFirst;
        double precision                   , intent(in) :: fieldAvg
        double precision                   , intent(in) :: fieldVar;
        integer                            , intent(in) :: comm, rang, nb_procs
        logical, dimension(1:), optional   , intent(in) :: calculate

        !OUTPUT
        double precision, dimension(:, :), intent(out), target :: randField;

        !LOCAL
        type(RF) :: RDF

        write(*,*) "Inside create_RF_Unstruct_noInit"

        !Initializing RF
        call init_RF(RDF, size(corrL), Nmc, comm, rang, nb_procs)
        RDF%xPoints   => xPoints
        RDF%randField => randField
        RDF%xNTotal    = size(RDF%xPoints, 2)
        RDF%corrL      = corrL
        RDF%corrMod    = corrMod
        RDF%Nmc        = Nmc
        RDF%method     = method
        RDF%seedStart  = seedStart
        RDF%margiFirst = margiFirst
        RDF%fieldAvg   = fieldAvg
        RDF%fieldVar   = fieldVar
        if(present(calculate)) RDF%calculate  = calculate

        call create_RF_Unstruct_Init(RDF)

    end subroutine create_RF_Unstruct_noInit

    !-----------------------------------------------------------------------------------------------
    !-----------------------------------------------------------------------------------------------
    !-----------------------------------------------------------------------------------------------
    !-----------------------------------------------------------------------------------------------
    subroutine create_RF_Unstruct_Init (RDF)
        !INPUT OUTPUT
        type(RF), intent(inout) :: RDF
        !LOCAL
        logical, dimension(:), allocatable :: effectCalc;

        write(*,*) "Inside create_RF_Unstruct_Init"

        !Discovering Global Extremes
        call get_Global_Extremes_Mesh(RDF%xPoints, RDF%xMinGlob, RDF%xMaxGlob)

        !Defining random seed
        call calculate_random_seed(RDF%seed, RDF%seedStart)
        call init_random_seed(RDF%seed)

        !Generating standard Gaussian Field
        call gen_Std_Gauss(RDF)

    end subroutine create_RF_Unstruct_Init

    !-----------------------------------------------------------------------------------------------
    !-----------------------------------------------------------------------------------------------
    !-----------------------------------------------------------------------------------------------
    !-----------------------------------------------------------------------------------------------
    subroutine gen_Std_Gauss (RDF)
        implicit none

        !INPUT OUTPUT
        type(RF), intent(inout) :: RDF

        !LOCAL VARIABLES
        integer :: i;

        write(*,*) "Inside gen_Std_Gauss"

        !Normalization
        do i = 1, RDF%nDim
            RDF%xPoints(i,:) = RDF%xPoints(i,:)/RDF%corrL(i)
            RDF%xMinGlob(i)  = RDF%xMinGlob(i)/RDF%corrL(i)
            RDF%xMaxGlob(i)  = RDF%xMaxGlob(i)/RDF%corrL(i)
        end do

        !call show_RF(RDF, "After Normalization")

        !Generating Standard Gaussian Field
        select case (RDF%method)
            case(SHINOZUKA)
                call gen_Std_Gauss_Shinozuka(RDF)
            case(ISOTROPIC)
                call gen_Std_Gauss_Isotropic(RDF)
            case(RANDOMIZATION)
                call gen_Std_Gauss_Randomization(RDF)
        end select

        !Reverting Normalization
        do i = 1, RDF%nDim
            RDF%xPoints(i,:) = RDF%xPoints(i,:)*RDF%corrL(i)
            RDF%xMinGlob(i)  = RDF%xMinGlob(i)*RDF%corrL(i)
            RDF%xMaxGlob(i)  = RDF%xMaxGlob(i)*RDF%corrL(i)
        end do

        !call show_RF(RDF, "After Revert Normalization")
    end subroutine gen_Std_Gauss

    !-----------------------------------------------------------------------------------------------
    !-----------------------------------------------------------------------------------------------
    !-----------------------------------------------------------------------------------------------
    !-----------------------------------------------------------------------------------------------
    subroutine multiVariateTransformation (margiFirst, fieldAvg, fieldVar, randField)

        implicit none

        !INPUT
        character (len=*), intent(in) :: margiFirst;
        double precision , intent(in) :: fieldAvg, fieldVar;

        !OUTPUT (IN)
        double precision, dimension(1:, 1:), intent(inout) :: randField;

        !LOCAL VARIABLES
        double precision :: normalVar, normalAvg
        integer          :: error, code, i

        select case (margiFirst)
        case("gaussian")
            normalVar = fieldVar
            normalAvg = fieldAvg
        case("lognormal")
            if(fieldAvg <= 0) then
                write(*,*) ""
                write(*,*) "ERROR - when using lognormal fieldAvg should be a positive number"
                call MPI_ABORT(MPI_COMM_WORLD, error, code)
            end if
            normalVar = log(1 + fieldVar/(fieldAvg**2))
            normalAvg = log(fieldAvg) - normalVar/2
        end select

        randField(:,:) = randField(:,:) * sqrt(normalVar) &
            + normalAvg;

        if (margiFirst == "lognormal") then
            randField(:,:) = exp(randField(:,:))
        end if

    end subroutine multiVariateTransformation

    !-----------------------------------------------------------------------------------------------
    !-----------------------------------------------------------------------------------------------
    !-----------------------------------------------------------------------------------------------
    !-----------------------------------------------------------------------------------------------
    subroutine gen_Std_Gauss_Shinozuka(RDF, randomK_in)

        implicit none

        !INPUT OUTPUT
        type(RF), intent(inout) :: RDF
        logical, intent(in), optional ::randomK_in

        !LOCAL
        double precision, dimension(:)   , allocatable :: phiK;
        double precision, dimension(:, :), allocatable :: kDelta;
        double precision, dimension(:)   , allocatable :: dgemm_mult;
        double precision, dimension(:,:) , allocatable :: k_dot_x_plus_phi;
        double precision :: ampMult
        integer :: n
        logical :: randomK

        write(*,*) "Inside Shinozuka"

        randomK = .false.
        if(present(randomK_in)) randomK = randomK_in

        write(*,*) "Defining kPoints"
        call set_kPoints(RDF, kDelta)
        call set_SkVec(RDF)

        write(*,*) "Calculating Samples"
        allocate(phiK (RDF%kNTotal));
        allocate(k_dot_x_plus_phi(RDF%xNTotal, RDF%kNTotal))

        !Generating random field samples
        if(.not. randomK) then
            write(*,*) "Shinozuka, k discrete"
            RDF%randField(:,:) = 0.0d0;
            ampMult = 2.0d0*sqrt(product(kDelta)/((2.0d0*PI)**(dble(RDF%nDim))))

            do n = 1, RDF%Nmc
                if(.not. RDF%calculate(n)) cycle
                call random_number(phiK(:))
                k_dot_x_plus_phi(:,:) = transpose(spread( source=2.0D0*pi*phiK , dim =2 , ncopies = RDF%xNTotal)) !2pi*phiK replicated xNTotal times

                call DGEMM_simple(RDF%xPoints, RDF%kPoints, k_dot_x_plus_phi, "T", "N") !x*k + 2pi*phiK
                call DGEMM_simple(cos(k_dot_x_plus_phi), reshape(source = ampMult * sqrt(RDF%SkVec), shape = [size(RDF%SkVec),1]) , RDF%randField(:,n:n), "N", "N")
            end do

            call show_RF(RDF, "Shinozuka Discrete After Generation")
            !call dispCarvalhol(RDF%randField, "RDF%randField")
        else
            write(*,*) "Shinozuka, k random"
            call show_RF(RDF, "Shinozuka Random Before Generation")
            RDF%randField(:,:) = 0.0d0;
            ampMult = 2.0d0*sqrt(1/(RDF%kNTotal*(2.0d0*PI)**(dble(RDF%nDim))))

            do n = 1, RDF%Nmc
                if(.not. RDF%calculate(n)) cycle
                write(*,*) "Before filling phiK"
                call random_number(phiK(:))
                write(*,*) "Before PhiK Replication"
                k_dot_x_plus_phi(:,:) = transpose(spread( source=2.0D0*pi*phiK , dim =2 , ncopies = RDF%xNTotal)) !2pi*phiK replicated xNTotal times
                write(*,*) "Before First DGEMM"
                call DGEMM_simple(RDF%xPoints, RDF%kPoints, k_dot_x_plus_phi, "T", "N") !x*k + 2pi*phiK
                write(*,*) "Before Second DGEMM"
                call DGEMM_simple(cos(k_dot_x_plus_phi), reshape(source = ampMult * sqrt(RDF%SkVec), shape = [size(RDF%SkVec),1]) , RDF%randField(:,n:n), "N", "N")
            end do

            call show_RF(RDF, "Shinozuka Random After Generation")
        end if

        if(allocated(dgemm_mult))       deallocate(dgemm_mult)
        if(allocated(phiK))             deallocate(phiK);
        if(allocated(kDelta))           deallocate(kDelta);
        if(allocated(k_dot_x_plus_phi)) deallocate(k_dot_x_plus_phi)

    end subroutine gen_Std_Gauss_Shinozuka

    !-----------------------------------------------------------------------------------------------
    !-----------------------------------------------------------------------------------------------
    !-----------------------------------------------------------------------------------------------
    !-----------------------------------------------------------------------------------------------
    subroutine gen_Std_Gauss_Randomization(RDF)

        implicit none

        !INPUT OUTPUT
        type(RF), intent(inout) :: RDF

        !LOCAL
        logical :: randomK;

        write(*,*) "Inside Randomization"

        randomK = .true.

        call gen_Std_Gauss_Shinozuka(RDF, randomK)

    end subroutine gen_Std_Gauss_Randomization

    !-----------------------------------------------------------------------------------------------
    !-----------------------------------------------------------------------------------------------
    !-----------------------------------------------------------------------------------------------
    !-----------------------------------------------------------------------------------------------

    subroutine gen_Std_Gauss_Isotropic(RDF)

        implicit none

        !INPUT OUTPUT
        type(RF), intent(inout) :: RDF

        !LOCAL
        double precision, dimension(:)  , allocatable :: gammaN, phiN, thetaN, psiN;
        double precision, dimension(:)  , allocatable :: rVec;
        logical         , dimension(:)  , allocatable :: effectCalc;
        double precision, dimension(1)                :: rMax
        integer          :: i, j, k, m, nDim;
        integer          :: xNTotal, rNTotal;
        integer          :: nb_procs, rang, code, error;
        double precision :: Sk, deltaKprod, step, rDelta;
        double precision, dimension(:), allocatable :: dgemm_mult;

!        nDim    = size(xPointsNorm, 1);
!        xNTotal = size(xPointsNorm, 2);
!
!        !Allocating
!        allocate(rVec (nDim));
!        allocate(dgemm_mult(xNTotal))
!
!        !r Definition
!        call set_rMax(corrMod, rMax)
!        rDelta  = 2d0*pi/(periodMult*sqrt(sum((xGlobRange)**2))) !Delta min in between two wave numbers to avoid periodicity
!        rNTotal = rAdjust*(ceiling(rMax(1)/rDelta) + 1);
!
!        !Generating random field samples
!        step      = rMax(1)/dble(rNTotal)
!        randField(:,:) = 0;
!        call init_random_seed(seed)
!
!        if (nDim == 2) then
!            allocate(psiN   (rNTotal));
!            allocate(thetaN (rNTotal));
!            allocate(gammaN (rNTotal));
!            do k = 1, Nmc
!                if(calculate(k)) then
!                    call random_number(psiN(:))
!                    call random_number(thetaN(:))
!                    call random_number(gammaN(:))
!                    psiN   = 2d0*pi*psiN
!                    thetaN = 2d0*pi*psiN
!                    gammaN = 2d0*pi*gammaN
!
!                    do j = 1, rNTotal
!                        rVec           = [cos(thetaN(j)) * (j-1)*step, &
!                            sin(thetaN(j)) * (j-1)*step]
!                        Sk             = get_SpectrumND([(j-1)*step], corrMod);
!                        call DGEMM ( "T", "N", xNTotal, 1, nDim, &
!                            1.0d0, xPointsNorm, nDim, rVec, nDim, 0.0d0, dgemm_mult, xNTotal)
!
!                        randField(:,k) = sqrt(Sk*(j-1)*(dble(step**2))) * gammaN(j) &
!                            * cos(                           &
!                            dgemm_mult                &
!                            + psiN(j)                 &
!                            )                          &
!                            + randField(:,k)
!                    end do
!                else
!                    randField(:,k) = 0.0
!                end if
!            end do
!
!        else if (nDim == 3) then
!            !write(*,*) "nDim = 3 !!!"
!            !write(*,*) "k = ",k;
!            allocate(psiN   (rNTotal));
!            allocate(thetaN (rNTotal));
!            allocate(phiN   (rNTotal));
!            allocate(gammaN (rNTotal));
!            do k = 1, Nmc
!                if(calculate(k)) then
!                    !write(*,*) "k = ",k;
!                    !write(*,*) "rNTotal = ",rNTotal;
!                    call random_number(phiN(:))
!                    call random_number(thetaN(:))
!                    call random_number(gammaN(:))
!                    call random_number(psiN(:))
!
!                    psiN   = 2*pi*psiN
!                    thetaN = 2*pi*psiN
!                    phiN   = pi*phiN
!                    gammaN = sqrt(12.0)*(gammaN -0.5d0)
!
!                    do j = 1, rNTotal
!                        !write(*,*) "j = ", j
!                        rVec           = [cos(thetaN(j))*sin(phiN(j)) * (j-1)*step, &
!                            sin(thetaN(j))*sin(phiN(j)) * (j-1)*step, &
!                            cos(phiN(j))                * (j-1)*step]
!                        Sk             = get_SpectrumND([(j-1)*step], corrMod);
!                        call DGEMM ( "T", "N", xNTotal, 1, nDim, &
!                            1.0d0, xPointsNorm, nDim, rVec, nDim, 0.0d0, dgemm_mult, xNTotal)
!                        randField(:,k) = sqrt(Sk*sin(phiN(j))*step*((j-1)*step)**2) * gammaN(j) &
!                            * cos(                                             &
!                            dgemm_mult                                   &
!                            + psiN(j)                                    &
!                            )                                            &
!                            + randField(:,k)
!                    end do
!                else
!                    randField(:,k) = 0.0
!                end if
!            end do
!
!        else
!            write(*,*) "ERROR The number of dimensions is not accepted in this method (Isotropic)";
!            write(*,*) "nDim = ", nDim;
!            stop
!        end if
!
!        !if(rang == 0) write(*,*) "Spectra (Sk) cut in: ", Sk
!
!        randField(:,:) = sqrt((1.0d0)/((2.0d0*pi)**(nDim)))&
!                         * randField(:,:)

        if(allocated(dgemm_mult))   deallocate(dgemm_mult)
        if(allocated(phiN))         deallocate(phiN);
        if(allocated(psiN))         deallocate(psiN);
        if(allocated(thetaN))       deallocate(thetaN);
        if(allocated(gammaN))       deallocate(gammaN);
        if(allocated(rVec))         deallocate(rVec);

    end subroutine gen_Std_Gauss_Isotropic

end module randomFieldND
!! Local Variables:
!! mode: f90
!! show-trailing-whitespace: t
!! f90-do-indent: 4
!! f90-if-indent: 4
!! f90-type-indent: 4
!! f90-program-indent: 4
!! f90-continuation-indent: 4
!! End:
!! vim: set sw=4 ts=8 et tw=80 smartindent : !!


!    !-----------------------------------------------------------------------------------------------
!    !-----------------------------------------------------------------------------------------------
!    !-----------------------------------------------------------------------------------------------
!    !-----------------------------------------------------------------------------------------------
!    subroutine createStandardGaussianFieldUnstructShinozuka (xPoints, corrL, corrMod, Nmc,  &
!                                                             MinBound, MaxBound, randField, &
!                                                             chosenSeed, communicator, calculate)
!
!        !INPUT
!        double precision, dimension(1:, 1:), intent(in) :: xPoints;
!        double precision, dimension(1:)    , intent(in) :: corrL;
!        integer                            , intent(in) :: Nmc;
!        character (len=*)                  , intent(in) :: corrMod;
!        double precision, dimension(1:)    , intent(in) :: MinBound, MaxBound
!        integer, dimension(1:), optional   , intent(in) :: chosenSeed
!        integer               , optional   , intent(in) :: communicator
!        logical, dimension(1:), optional   , intent(in) :: calculate
!
!        !OUTPUT
!        double precision, dimension(:, :), intent(out) :: randField;
!
!        !LOCAL VARIABLES
!        integer         , dimension(:)  , allocatable :: kNStep;
!        double precision, dimension(:)  , allocatable :: kMax;
!        double precision, dimension(:,:), allocatable :: kSign, phiN, xPointsNorm;
!        double precision, dimension(:)  , allocatable :: kVec, kVecUnsigned; !Allocated in function
!        double precision, dimension(:)  , allocatable :: deltaK, kDelta;
!        double precision, dimension(:)  , allocatable :: xMaxGlob, xMinGlob;
!        logical         , dimension(:)  , allocatable :: effectCalc;
!        integer          :: effectComm
!        integer          :: i, j, k, m, nDim;
!        integer          :: xNTotal, kNTotal;
!        integer          :: rang, code, error;
!        double precision :: Sk, deltaKprod;
!        double precision :: pi = 3.1415926535898, zero = 0d0;
!        double precision, dimension(:), allocatable :: dgemm_mult;
!        !integer, dimension(:), allocatable :: testSeed!TEST
!
!        !write(*,*) "INSIDE 'createStandardGaussianFieldUnstructShinozuka'"
!
!        !call MPI_COMM_SIZE(MPI_COMM_WORLD, nb_procs, code)
!        call MPI_COMM_RANK(MPI_COMM_WORLD, rang, code)
!
!        nDim    = size(xPoints, 1);
!        xNTotal = size(xPoints, 2);
!
!        !write(*,*) "nDim =", nDim
!        !write(*,*) "xNTotal =", xNTotal
!        !call dispCarvalhol(xPoints(:,1:20), "xPoints(:,1:20)")
!
!        allocate(effectCalc(Nmc))
!        effectCalc(:) = .true.
!        if(present(calculate)) effectCalc = calculate
!
!        if(present(communicator)) then
!            effectComm = communicator
!        else
!            effectComm = MPI_COMM_WORLD
!        end if
!
!        !Normalization
!        allocate (xPointsNorm (nDim, xNTotal))
!        xPointsNorm(:,:) = xPoints(:,:)
!        !call dispCarvalhol(xPointsNorm(:,1:20), "xPointsNorm(:,1:20) BEFORE")
!        do i = 1, nDim
!            if(corrL(i) /= 1d0) then
!                xPointsNorm(i,:) = xPoints(i,:)/corrL(i)
!                xMinGlob(i) = MinBound(i)/corrL(i)
!                xMaxGlob(i) = MaxBound(i)/corrL(i)
!            else
!                xPointsNorm(i,:) = xPoints(i,:)
!                xMinGlob(i) = MinBound(i)
!                xMaxGlob(i) = MaxBound(i)
!            end if
!        end do
!
!        !call dispCarvalhol(xPointsNorm(:,1:20), "xPointsNorm(:,1:20) AFTER")
!
!        !if(rang == 0) write(*,*) ">>>>>>>>> Variables initialization: kMax, kDelta, kNStep, xMinGlob, xMaxGlob";
!        !Allocating
!        allocate(kMax   (nDim));
!        allocate(kNStep (nDim));
!        allocate(kDelta (nDim));
!        allocate(dgemm_mult(xNTotal))
!
!        call set_kMaxND(corrMod, kMax) !Defining kMax according to corrMod
!        kDelta  = 2*pi/(periodMult*(xMaxGlob - xMinGlob)) !Delta min in between two wave numbers to avoid periodicity
!        kNStep  = kAdjust*(ceiling(kMax/kDelta) + 1);
!        kNTotal = product(kNStep);
!
!        !if(rang == 0) write(*,*) "Nmc     = ", Nmc
!        !if(rang == 0) write(*,*) "kNTotal = ", kNTotal
!        !if(rang == 0) write(*,*) "kDelta  = ", kDelta
!        !if(rang == 0) write(*,*) "kNStep  = ", kNStep
!        !if(rang == 0) write(*,*) "xMinGlob  = ", xMinGlob
!        !if(rang == 0) write(*,*) "xMaxGlob  = ", xMaxGlob
!
!        if(kNTotal < 1) then
!            write(*,*) "ERROR - In 'createStandardGaussianFieldUnstruct': kNTotal should be a positive integer (possibly a truncation problem)"
!            call MPI_ABORT(effectComm, error, code)
!        endif
!
!        !Random Field
!        allocate(deltaK      (nDim));
!        allocate(kVec        (nDim));
!        allocate(kVecUnsigned(nDim));
!        allocate(kSign       (2**(nDim-1), nDim));
!        allocate(phiN        (size(kSign,1), kNTotal));
!
!
!        if (size(randField, 1) /= xNTotal .or. size(randField, 2) /= Nmc) then
!            write(*,*) "ERROR - In 'createStandardGaussianFieldUnstruct': randfield dimensions are imcompatible with the coordinates (xPoints)"
!            write(*,*) "shape(randfield(:,:)) = ", size(randField, 1), size(randField, 2)
!            call MPI_ABORT(effectComm, error, code)
!        end if
!
!        randField(:,:) = 0;
!        deltaK(:)      = 0;
!        deltaK(:)      = (kMax)/(kNStep-1); !Defines deltaK
!        call set_kSign(kSign) !Set the sign permutations for kVec
!
!        !Initializing the seed
!        !call calculate_random_seed(testSeed, 0) !TEST
!        !call init_random_seed(testSeed) !TEST
!        if(present(chosenSeed)) then
!            call init_random_seed(chosenSeed)
!        else
!            call init_random_seed()
!        end if
!
!        !Generating random field samples
!        do k = 1, Nmc
!            if(effectCalc(k)) then
!                call random_number(phiN(:,:))
!                do j = 1, kNTotal
!                    call get_Permutation(j, kMax, kNStep, kVecUnsigned);
!                    do m = 1, size(kSign,1)
!                        kVec           = kVecUnsigned * kSign(m, :)
!                        Sk             = get_SpectrumND(kVec, corrMod);
!                        call DGEMM ( "T", "N", xNTotal, 1, nDim, &
!                            1.0d0, xPointsNorm, nDim, kVec, nDim, 0.0d0, dgemm_mult, xNTotal)
!                            randField(:,k) = sqrt(Sk)                 &
!                            * cos(                   &
!                            dgemm_mult        &
!                            + 2*pi*phiN(m, j) &
!                            )                  &
!                            + randField(:,k)
!                    end do
!                end do
!            else
!                randField(:,k) = 0.0
!            end if
!        end do
!
!        !if(rang == 0) write(*,*) "Spectra (Sk) cut in: ", Sk
!
!        randField(:,:) = 2*sqrt(product(deltaK)/((2*pi)**(nDim))) &
!            * randField(:,:) !Obs: sqrt(product(corrL)) is not needed because of normalization
!
!        !call dispCarvalhol(randField(:,:), "randField(:,:) (iNSIDE sHINOZUKA)")
!
!        if(allocated(dgemm_mult))   deallocate(dgemm_mult)
!        if(allocated(deltaK))       deallocate(deltaK);
!        if(allocated(kVecUnsigned)) deallocate(kVecUnsigned);
!        if(allocated(kVec))         deallocate(kVec);
!        if(allocated(kMax))         deallocate(kMax);
!        if(allocated(kNStep))       deallocate(kNStep);
!        if(allocated(kDelta))       deallocate(kDelta);
!        if(allocated(kSign))        deallocate(kSign);
!        if(allocated(phiN))         deallocate(phiN);
!        if(allocated(kVecUnsigned)) deallocate(kVecUnsigned);
!        if(allocated(xMinGlob))     deallocate(xMinGlob);
!        if(allocated(xMaxGlob))     deallocate(xMaxGlob);
!        if(allocated(xPointsNorm))  deallocate (xPointsNorm);
!        if(allocated(effectCalc))   deallocate (effectCalc);
!
!    end subroutine createStandardGaussianFieldUnstructShinozuka
!
!    !-----------------------------------------------------------------------------------------------
!    !-----------------------------------------------------------------------------------------------
!    !-----------------------------------------------------------------------------------------------
!    !-----------------------------------------------------------------------------------------------
!    subroutine createStandardGaussianFieldUnstructIsotropic (xPoints, corrL, corrMod, Nmc,  &
!                                                             MinBound, MaxBound, randField, &
!                                                             chosenSeed, communicator, calculate)
!
!        !INPUT
!        double precision, dimension(1:, 1:), intent(in) :: xPoints;
!        double precision, dimension(1:)    , intent(in) :: corrL;
!        integer                            , intent(in) :: Nmc;
!        character (len=*)                  , intent(in) :: corrMod;
!        double precision, dimension(1:)    , intent(in) :: MinBound, MaxBound
!        integer, dimension(1:), optional   , intent(in) :: chosenSeed
!        integer               , optional   , intent(in) :: communicator
!        logical, dimension(1:), optional   , intent(in) :: calculate
!        !OUTPUT
!        double precision, dimension(1:, 1:), intent(out) :: randField;
!
!        !LOCAL VARIABLES
!        double precision, dimension(:,:), allocatable :: xPointsNorm;
!        double precision, dimension(:)  , allocatable :: gammaN, phiN, thetaN, psiN;
!        double precision, dimension(:)  , allocatable :: rVec;
!        double precision, dimension(:)  , allocatable :: xMaxGlob, xMinGlob, amplitudeVec;
!        logical         , dimension(:)  , allocatable :: effectCalc;
!        double precision, dimension(1)                :: rMax
!        integer          :: effectComm
!        integer          :: i, j, k, m, nDim;
!        integer          :: xNTotal, rNTotal;
!        integer          :: nb_procs, rang, code, error;
!        double precision :: Sk, deltaKprod, step, rDelta;
!        double precision, dimension(:), allocatable :: dgemm_mult;
!        !integer, dimension(:), allocatable :: testSeed!TEST
!
!
!        write(*,*) "INSIDE 'createStandardGaussianFieldUnstructIsotropic'"
!
!        call MPI_COMM_SIZE(MPI_COMM_WORLD, nb_procs, code)
!        call MPI_COMM_RANK(MPI_COMM_WORLD, rang, code)
!
!        nDim    = size(xPoints, 1);
!        xNTotal = size(xPoints, 2);
!
!        !write(*,*) "nDim =", nDim
!        !write(*,*) "xNTotal =", xNTotal
!        !call dispCarvalhol(xPoints, "xPoints")
!
!        allocate(xPointsNorm (nDim, xNTotal))
!        allocate(rVec   (nDim));
!        allocate(xMinGlob(nDim))
!        allocate(xMaxGlob(nDim))
!        allocate(amplitudeVec(nDim))
!        allocate(dgemm_mult(xNTotal))
!
!        allocate(effectCalc(Nmc))
!        effectCalc(:) = .true.
!        if(present(calculate)) effectCalc = calculate
!
!        if(present(communicator)) then
!            effectComm = communicator
!        else
!            effectComm = MPI_COMM_WORLD
!        end if
!
!        !Normalization
!        !write(*,*) "Normalizing"
!        !write(*,*) "MinBound = ", MinBound;
!        !write(*,*) "MaxBound = ", MaxBound;
!        !write(*,*) "corrL = ", corrL;
!
!        do i = 1, nDim
!            if(corrL(i) /= 1d0) then
!                xPointsNorm(i,:) = xPoints(i,:)/corrL(i)
!                xMinGlob(i) = MinBound(i)/corrL(i)
!                xMaxGlob(i) = MaxBound(i)/corrL(i)
!            else
!                xPointsNorm(i,:) = xPoints(i,:)
!                xMinGlob(i) = MinBound(i)
!                xMaxGlob(i) = MaxBound(i)
!            end if
!        end do
!
!        !write(*,*) "xMaxGlob = ", xMaxGlob
!        !write(*,*) "xMinGlob = ", xMinGlob
!
!        !Setting kMax e kStep
!        !write(*,*) "Setting kMax e kStep"
!        call set_rMax(corrMod, rMax)
!        rDelta  = 2*pi/(periodMult*sqrt(sum((xMaxGlob - xMinGlob)**2))) !Delta min in between two wave numbers to avoid periodicity
!        rNTotal = rAdjust*(ceiling(rMax(1)/rDelta) + 1);
!
!        !rNTotal = ceiling(rMax(1) * dble(pointsPerCorrl))
!        !rMax(1)        = sqrt(sum((xMaxGlob - xMinGlob)**2))
!        !rNTotal        = N
!        !rCrit          = maxval(xMaxGlob - xMinGlob)
!        !rNTotal        = ceiling(sqrt(dble(N)))
!
!        !Random Field
!        randField = 0;
!        step      = rMax(1)/dble(rNTotal)
!
!        !if(rang == 0) write(*,*) "rMax(1) = ",rMax(1);
!        !if(rang == 0) write(*,*) "rNTotal = ",rNTotal;
!        !if(rang == 0) write(*,*) "rDelta  = ",rDelta;
!        !if(rang == 0) write(*,*) "step    = ",step;
!
!        !Initializing the seed
!        !call calculate_random_seed(testSeed, 0)!TEST
!        !call init_random_seed(testSeed)!TEST
!        if(present(chosenSeed)) then
!            call init_random_seed(chosenSeed)
!        else
!            call init_random_seed()
!        end if
!
!        if (nDim == 2) then
!            allocate(psiN        (rNTotal)); !Out of phase
!            allocate(thetaN      (rNTotal));
!            allocate(gammaN      (rNTotal));
!            do k = 1, Nmc
!                if(effectCalc(k)) then
!                    !if(rang == 0) write(*,*) "k = ",k;
!                    !write(*,*) "rNTotal = ",rNTotal;
!                    call random_number(psiN(:))
!                    call random_number(thetaN(:))
!                    call random_number(gammaN(:))
!                    psiN   = 2*pi*psiN
!                    thetaN = 2*pi*psiN
!                    gammaN = 2*pi*gammaN
!
!                    do j = 1, rNTotal
!                        rVec           = [cos(thetaN(j)) * j*step, &
!                            sin(thetaN(j)) * j*step]
!                        Sk             = get_SpectrumND([j*step], corrMod);
!                        call DGEMM ( "T", "N", xNTotal, 1, nDim, &
!                            1.0d0, xPointsNorm, nDim, rVec, nDim, 0.0d0, dgemm_mult, xNTotal)
!                        !call dispCarvalhol(dgemm_mult(1:20), "dgemm_mult(1:20)")
!                        randField(:,k) = sqrt(Sk*j*(step**2)) * gammaN(j) &
!                            * cos(                           &
!                            dgemm_mult                &
!                            + psiN(j)                 &
!                            )                          &
!                            + randField(:,k)
!                    end do
!                else
!                    randField(:,k) = 0.0
!                end if
!            end do
!
!        else if (nDim == 3) then
!            !write(*,*) "nDim = 3 !!!"
!            !write(*,*) "k = ",k;
!            allocate(psiN   (rNTotal));
!            allocate(thetaN (rNTotal));
!            allocate(phiN   (rNTotal));
!            allocate(gammaN (rNTotal));
!            do k = 1, Nmc
!                if(effectCalc(k)) then
!                    !write(*,*) "k = ",k;
!                    !write(*,*) "rNTotal = ",rNTotal;
!                    call random_number(phiN(:))
!                    call random_number(thetaN(:))
!                    call random_number(gammaN(:))
!                    call random_number(psiN(:))
!
!                    psiN   = 2*pi*psiN
!                    thetaN = 2*pi*psiN
!                    phiN   = pi*phiN
!                    gammaN = sqrt(12.0)*(gammaN -0.5d0)
!
!                    do j = 1, rNTotal
!                        !write(*,*) "j = ", j
!                        rVec           = [cos(thetaN(j))*sin(phiN(j)) * j*step, &
!                            sin(thetaN(j))*sin(phiN(j)) * j*step, &
!                            cos(phiN(j))                * j*step]
!                        Sk             = get_SpectrumND([j*step], corrMod);
!                        call DGEMM ( "T", "N", xNTotal, 1, nDim, &
!                            1.0d0, xPointsNorm, nDim, rVec, nDim, 0.0d0, dgemm_mult, xNTotal)
!                        randField(:,k) = sqrt(Sk*sin(phiN(j))*step*(j*step)**2) * gammaN(j) &
!                            * cos(                                             &
!                            dgemm_mult                                   &
!                            + psiN(j)                                    &
!                            )                                            &
!                            + randField(:,k)
!                    end do
!                else
!                    randField(:,k) = 0.0
!                end if
!            end do
!        else
!            write(*,*) "The number of dimensions is not accepted in this method (Victor). nDim = ", nDim;
!            call MPI_ABORT(MPI_COMM_WORLD, error, code)
!        end if
!
!        !if(rang == 0) write(*,*) "Spectra (Sk) cut in: ", Sk
!
!        randField(:,:) = sqrt((1.0d0)/((2.0d0*pi)**(nDim)))&
!                         * randField(:,:)
!
!        if(allocated(dgemm_mult))   deallocate(dgemm_mult)
!        if(allocated(phiN))         deallocate(phiN);
!        if(allocated(psiN))         deallocate(psiN);
!        if(allocated(thetaN))       deallocate(thetaN);
!        if(allocated(gammaN))       deallocate(gammaN);
!        if(allocated(xMinGlob))     deallocate(xMinGlob);
!        if(allocated(xMaxGlob))     deallocate(xMaxGlob);
!        if(allocated(xPointsNorm))  deallocate (xPointsNorm);
!        if(allocated(rVec))         deallocate(rVec);
!        if(allocated(amplitudeVec)) deallocate(amplitudeVec)
!
!    end subroutine createStandardGaussianFieldUnstructIsotropic
