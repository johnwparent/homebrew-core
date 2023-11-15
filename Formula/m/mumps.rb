class Mumps < Formula
  desc "MUltifrontal Massively Parallel sparse direct Solver"
  homepage "https://mumps-solver.org/"
  url "https://mumps-solver.org/MUMPS_5.6.2.tar.gz"
  sha256 "13a2c1aff2bd1aa92fe84b7b35d88f43434019963ca09ef7e8c90821a8f1d59a"
  license "CECILL-C"

  # Core dependencies
  depends_on "gcc"
  depends_on "openblas"

  def install
    make_args = ["RANLIB=echo", "CDEFS=-DAdd_"]
    # floating point opts
    optf = ["OPTF=-O"]
    gcc_major_ver = Formula["gcc"].any_installed_version.major
    optf << "-fallow-argument-mismatch" if gcc_major_ver >= 10
    make_args << optf.join(" ")
    orderingsf = "-Dpord"

    makefile = "Makefile.G95.SEQ"
    cp "Make.inc/" + makefile, "Makefile.inc"

    make_args += ["CC=#{ENV["CC"]} -fPIC",
                  "FC=gfortran -fPIC -fopenmp",
                  "FL=gfortran -fPIC -fopenmp"]

    make_args << "ORDERINGSF=#{orderingsf}"

    # Default lib args
    blas_lib = "-L#{Formula["openblas"].opt_lib} -lopenblas"
    make_args << "LIBBLAS=#{blas_lib}"
    make_args << "LAPACK=#{blas_lib}"

    ENV.deparallelize

    system "make", "allshared", *make_args

    so = OS.mac? ? "dylib" : "so"

    lib.install Dir["lib/*.#{so}"]
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
    cd testpath do
      mumps_path = Formula["mumps"].pkgshare/"examples"
      system "#{mumps_path}/c_example"
      system "#{mumps_path}/ssimpletest < input_simpletest_real"
      system "#{mumps_path}/dsimpletest < input_simpletest_real"
      system "#{mumps_path}/csimpletest < input_simpletest_cmplx"
      system "#{mumps_path}/zsimpletest < input_simpletest_cmplx"
    end
  end
end
