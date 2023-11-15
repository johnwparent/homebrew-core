# Documentation: https://docs.brew.sh/Formula-Cookbook
#                https://rubydoc.brew.sh/Formula
# PLEASE REMOVE ALL GENERATED COMMENTS BEFORE SUBMITTING YOUR PULL REQUEST!
class MumpsHpc < Formula
  desc ""
  homepage ""
  url "https://mumps-solver.org/MUMPS_5.6.2.tar.gz"
  sha256 "13a2c1aff2bd1aa92fe84b7b35d88f43434019963ca09ef7e8c90821a8f1d59a"
  license ""

  depends_on "openblas"
  depends_on "gcc"

  # Parallel dependencies
    depends_on "open-mpi"
    depends_on "scalapack"

    depends_on "scotch"
    depends_on "parmetis"

  def install

    make_args = ["RANLIB=echo", "CDEFS=-DAdd_"]
    # floating point opts
    optf = ["OPTF=-O"]
    gcc_major_ver = Formula["gcc"].any_installed_version.major
    optf << "-fallow-argument-mismatch" if gcc_major_ver >= 10
    make_args << optf.join(" ")
    orderingsf = "-Dpord"

    makefile = "Makefile.G96.PAR"
    cp "Make.inc/" + makefile, "Makefile.inc"
  
    if build.with?("with-parallel")
      scalapack_libs = "-L#{Formula["scalapack"].opt_lib} -lscalapack"
      make_args += ["CC=mpicc -fPIC",
                    "FC=mpif90 -fPIC",
                    "FL=mpif90 -fPIC",
                    "SCALAP=#{scalapack_libs}",
                    "INCPAR=", # Let MPI compilers fill in the blanks.
                    "LIBPAR=$(SCALAP)"]
    else
      make_args += ["CC=#{ENV["CC"]} -fPIC",
      "FC=gfortran -fPIC -fopenmp",
      "FL=gfortran -fPIC -fopenmp"]
    end

    if build.with?("with-hpc")

      # Include & link scotch

      scotch = Formula["scotch"]
      scotch_root_dir = scotch.opt_prefix
      scotch_inc_dir = scotch.inc_prefix
      make_args += ["SCOTCHDIR=#{scotch_root_dir}", "ISCOTCH=-I#{scotch_inc_dir}"]

      scotch_libs = "-L$(SCOTCHDIR)/lib -lptscotch -lptscotcherr -lptscotcherrexit -lscotch"
      scotch_metis_link = "-lptscotchparmetis"
      scotch_ordering = " -Dptscotch"
      scotch_libs += scotch_metis_link
      make_args << "LSCOTCH=#{scotch_libs}"

      # Setup parmetis
      metis_ordering = " -Dparmetis"
      metis_libs = "-L#{Formula["parmetis"].opt_lib} -lparmetis -L#{Formula["metis"].opt_lib} -lmetis"
      make_args += ["LMETISDIR=#{Formula["parmetis"].opt_lib}",
                  "IMETIS=#{Formula["parmetis"].opt_include}",
                  "LMETIS=#{metis_libs}"]

      orderingsf << scotch_ordering << metis_ordering

    end
    # Default lib args
    blas_lib = "-L#{Formula["openblas"].opt_lib} -lopenblas"
    make_args << "LIBBLAS=#{blas_lib}"
    make_args << "LAPACK=#{blas_lib}"

    ENV.deparallelize

    system "make", "allshared", *make_args

    so = OS.mac? ? "dylib" : "so"

    lib.install Dir["lib/*"]
    lib.install "libseq/libmpiseq.#{so}"

    inreplace "examples/Makefile" do |s|
      s.change_make_var! "libdir", lib
    end

    libexec.install "include"
    include.install_symlink Dir[libexec/"include/*"]

    (libexec/"include").install Dir["libseq/*.h"]

    doc.install Dir["doc/*.pdf"]
    pkgshare.install "examples"

    prefix.install "Makefile.inc"  # For the record.
    File.open(prefix/"make_args.txt", "w") do |f|
      f.puts(make_args.join(" "))  # Record options passed to make.
    end
  end

  test do
    cd testpath/"examples" do
      mpirun = "mpirun -np 2"
      system "#{mpirun} ./c_example"
      system "#{mpirun} ./ssimpletest < input_simpletest_real"
      system "#{mpirun} ./dsimpletest < input_simpletest_real"
      system "#{mpirun} ./csimpletest < input_simpletest_cmplx"
      system "#{mpirun} ./zsimpletest < input_simpletest_cmplx"
    end
  end
end
