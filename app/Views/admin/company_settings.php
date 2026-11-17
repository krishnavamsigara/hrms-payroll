<!DOCTYPE html>

<html class="h-full bg-slate-50" lang="en"><head>
<meta charset="utf-8"/>
<meta content="width=device-width, initial-scale=1.0" name="viewport"/>
<title>Company Settings &amp; Payroll Configuration - BloomHR</title>
<!-- Tailwind CSS v3 with Forms & Container Queries -->
<script src="https://cdn.tailwindcss.com?plugins=forms,container-queries"></script>
<!-- Font Awesome Icons -->
<!-- Google Font -->
  <link
    href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@300;400;500;600;700;800&display=swap"
    rel="stylesheet">

  <!-- Font Awesome -->
  <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/5.15.4/css/all.min.css">

  <!-- AdminLTE -->
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/admin-lte@3.2/dist/css/adminlte.min.css">

<!-- Font Awesome 6.4.0 - Supports fa-solid and fa-regular -->
<link rel="stylesheet"
      href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
<style>

/* BloomHR page typography and background */
html,
body,
.content-wrapper {
    font-family: 'Plus Jakarta Sans', sans-serif !important;
}

.content-wrapper {
    background: #f8fafc !important;
    color: #1e293b;
    min-height: 100vh;
}

.content-header {
    padding: 22px 15px 12px;
}

.content-header h1 {
    color: #1e293b !important;
    font-family: 'Plus Jakarta Sans', sans-serif !important;
    font-size: 1.5rem !important;
    font-weight: 700 !important;
    letter-spacing: -0.4px;
}

.content-header p {
    color: #64748b !important;
    font-size: 13px;
    line-height: 1.6;
}

.content {
    padding: 0 15px 25px;
}

/* ---------- Theme colors ---------- */

:root {
    --bloom-primary: #4a00e0;
    --bloom-dark: #2a0080;
    --bloom-deep: #120038;
    --bloom-light: #eef2ff;
    --bloom-bg: #f8fafc;
    --bloom-text: #1e293b;
    --bloom-muted: #64748b;
    --bloom-border: #e2e8f0;
    --bloom-success: #10b981;
    --bloom-danger: #dc2626;
}

/* ---------- Cards ---------- */

.content-wrapper .card {
    background: #ffffff;
    border: 1px solid #edf0f7 !important;
    border-radius: 16px !important;
    box-shadow: 0 4px 18px rgba(30, 41, 59, 0.045) !important;
    overflow: hidden;
    transition: box-shadow 0.2s ease, transform 0.2s ease;
}

.content-wrapper .card:hover {
    box-shadow: 0 7px 24px rgba(42, 0, 128, 0.075) !important;
}

.content-wrapper .card-header {
    padding: 20px 22px 10px !important;
    background: #ffffff !important;
    border-bottom: 1px solid #f1f5f9 !important;
}

.content-wrapper .card-title {
    color: #1e293b !important;
    font-size: 15px;
    font-weight: 700 !important;
    line-height: 1.5;
    float: none;
}

.content-wrapper .card-title i {
    color: var(--bloom-primary) !important;
}

.content-wrapper .card-body {
    padding: 22px !important;
}

.content-wrapper .card-outline.card-primary,
.content-wrapper .card-outline.card-info,
.content-wrapper .card-outline.card-success,
.content-wrapper .card-outline.card-warning {
    border-top: 3px solid var(--bloom-primary) !important;
}

/* ---------- Labels ---------- */

.content-wrapper .form-group {
    margin-bottom: 19px;
}

.content-wrapper label {
    display: block;
    color: #475569 !important;
    font-size: 12px;
    font-weight: 700 !important;
    margin-bottom: 7px;
    letter-spacing: 0.15px;
}

.content-wrapper label .text-danger {
    color: #dc2626 !important;
}

/* ---------- Input fields ---------- */

.content-wrapper .form-control {
    width: 100%;
    min-height: 42px;
    background-color: #ffffff;
    color: #1e293b;
    border: 1px solid #dfe5ef;
    border-radius: 9px;
    padding: 9px 12px;
    font-size: 13px;
    font-weight: 500;
    box-shadow: none;
    transition: border-color 0.2s ease, box-shadow 0.2s ease;
}

.content-wrapper textarea.form-control {
    min-height: auto;
    resize: vertical;
    line-height: 1.6;
}

.content-wrapper .form-control:hover {
    border-color: #c4b5fd;
}

.content-wrapper .form-control:focus {
    background-color: #ffffff;
    border-color: var(--bloom-primary);
    box-shadow: 0 0 0 3px rgba(74, 0, 224, 0.10);
    outline: none;
}

.content-wrapper .form-control::placeholder {
    color: #94a3b8;
    font-weight: 400;
    opacity: 1;
}

.content-wrapper .form-control-file {
    width: 100%;
    color: #64748b;
    font-size: 12px;
    padding: 8px 0;
}

.content-wrapper input[type="file"]::file-selector-button {
    border: 0;
    background: #eef2ff;
    color: #4a00e0;
    border-radius: 6px;
    padding: 7px 10px;
    margin-right: 10px;
    font-weight: 700;
    cursor: pointer;
}

/* ---------- Input groups ---------- */

.content-wrapper .input-group {
    align-items: stretch;
}

.content-wrapper .input-group .form-control {
    min-width: 0;
    height: 42px;
}

.content-wrapper .input-group-text {
    background: #f1f5f9;
    color: #64748b;
    border: 1px solid #dfe5ef;
    border-radius: 0 9px 9px 0;
    font-size: 12px;
    font-weight: 700;
}

.content-wrapper .input-group .form-control:not(:last-child) {
    border-radius: 9px 0 0 9px;
}

/* ---------- Buttons ---------- */

.content-wrapper .btn {
    border-radius: 9px;
    font-size: 12px;
    font-weight: 700 !important;
    padding: 9px 15px;
    transition: all 0.2s ease;
}

.content-wrapper .btn-primary {
    color: #ffffff !important;
    background: linear-gradient(135deg, #4a00e0, #6425e8) !important;
    border: 1px solid #4a00e0 !important;
    box-shadow: 0 3px 9px rgba(74, 0, 224, 0.16);
}

.content-wrapper .btn-primary:hover,
.content-wrapper .btn-primary:focus {
    color: #ffffff !important;
    background: linear-gradient(135deg, #2a0080, #4a00e0) !important;
    border-color: #2a0080 !important;
    box-shadow: 0 5px 13px rgba(74, 0, 224, 0.23);
    transform: translateY(-1px);
}

.content-wrapper .btn-outline-secondary {
    background: #ffffff;
    color: #475569;
    border: 1px solid #dbe2ea;
}

.content-wrapper .btn-outline-secondary:hover {
    background: #f1f5f9;
    color: #1e293b;
    border-color: #cbd5e1;
}

.content-wrapper .btn i {
    margin-right: 4px;
}

/* ---------- Text and helper labels ---------- */

.content-wrapper .text-muted,
.content-wrapper small.text-muted {
    color: #64748b !important;
}

.content-wrapper small {
    font-size: 11px;
    line-height: 1.6;
}

.content-wrapper code {
    color: #4a00e0;
    background: #eef2ff;
    padding: 3px 6px;
    border-radius: 5px;
    font-size: 11px;
    overflow-wrap: anywhere;
}

.content-wrapper .text-primary {
    color: #4a00e0 !important;
}

.content-wrapper .text-info {
    color: #4a00e0 !important;
}

.content-wrapper .text-success {
    color: #059669 !important;
}

.content-wrapper .text-warning {
    color: #d97706 !important;
}

/* ---------- Logo and watermark preview ---------- */

.content-wrapper .img-thumbnail {
    width: 58px !important;
    height: 58px !important;
    padding: 5px;
    object-fit: contain;
    background: #ffffff;
    border: 1px solid #e2e8f0;
    border-radius: 11px;
}

.content-wrapper .border-top {
    border-color: #edf0f7 !important;
}

/* ---------- Payroll preview ---------- */

#cyclePreviewText {
    color: #334155 !important;
    line-height: 1.9;
    font-size: 12px;
}

.content-wrapper .card-body .bg-light {
    background: #f5f3ff !important;
    border: 1px solid #e5ddff !important;
    border-radius: 12px !important;
}

#cyclePreviewText strong {
    color: #4a00e0;
    font-weight: 700;
}

/* ---------- Alerts ---------- */

.content-wrapper .alert {
    border: 0;
    border-radius: 12px;
    padding: 14px 18px;
    font-size: 13px;
}

.content-wrapper .alert-success {
    color: #065f46;
    background: #ecfdf5;
    border-left: 4px solid #10b981;
}

.content-wrapper .alert-danger {
    color: #991b1b;
    background: #fef2f2;
    border-left: 4px solid #dc2626;
}

.content-wrapper .alert .close {
    font-size: 20px;
    opacity: 0.65;
}

/* ---------- Submission card ---------- */

.content-wrapper .card.p-3 {
    padding: 18px !important;
    border-radius: 13px !important;
}

.content-wrapper .card.p-3 .btn {
    margin-bottom: 0;
}

/* ---------- Form validation ---------- */

.content-wrapper .form-control:invalid:not(:placeholder-shown) {
    border-color: #dfe5ef;
}

.content-wrapper .form-control:focus:invalid {
    border-color: #dc2626;
    box-shadow: 0 0 0 3px rgba(220, 38, 38, 0.08);
}

/* ---------- Responsive layout ---------- */

@media (max-width: 991.98px) {
    .content-header {
        padding-top: 16px;
    }

    .content-wrapper .card-body {
        padding: 18px !important;
    }

    .content-wrapper .card-header {
        padding: 17px 18px 10px !important;
    }
}

@media (max-width: 767.98px) {
    .content-header h1 {
        font-size: 20px !important;
        line-height: 1.5;
    }

    .content-header .col-sm-6.text-sm-right {
        text-align: left !important;
    }

    .content-header .btn {
        margin-bottom: 8px;
    }

    .content-wrapper .card-body {
        padding: 15px !important;
    }

    .content-wrapper .card-header {
        padding: 16px 15px 10px !important;
    }

    .content-wrapper .form-group {
        margin-bottom: 16px;
    }

    .content-wrapper .card.p-3 .text-right {
        text-align: left !important;
    }

    .content-wrapper .card.p-3 .btn {
        margin: 4px 4px 4px 0;
    }
}


</style>

<div class="content-wrapper p-3" style="background: #f8fafc;">
  <!-- Content Header -->
  <div class="content-header pb-2">
    <div class="container-fluid">
      <div class="row align-items-center">
        <div class="col-sm-6">
          <h1 class="m-0 font-weight-bold text-dark" style="font-size: 1.5rem;">
            <i class="fas fa-building text-primary mr-2"></i> Company Settings & Payroll Configuration
          </h1>
          <p class="text-muted small mb-0 mt-1">
            Configure company branding, official address, statutory identifiers, and attendance/payroll cut-off periods.
          </p>
        </div>
        <div class="col-sm-6 text-sm-right mt-2 mt-sm-0">
          <a href="<?= base_url('admin/payroll') ?>" class="btn btn-outline-secondary btn-sm font-weight-bold mr-2">
            <i class="fas fa-calculator mr-1"></i> Payroll Processing
          </a>
          <button type="submit" form="companySettingsForm" class="btn btn-primary btn-sm font-weight-bold shadow-sm" style="background: #4a00e0; border-color: #4a00e0;">
            <i class="fas fa-save mr-1"></i> Save Changes
          </button>
        </div>
      </div>
    </div>
  </div>

  <!-- Main Content -->
  <section class="content">
    <div class="container-fluid">

      <!-- Alerts -->
      <?php if (session()->getFlashdata('success')): ?>
        <div class="alert alert-success alert-dismissible fade show shadow-sm" role="alert">
          <i class="fas fa-check-circle mr-2"></i> <?= session()->getFlashdata('success') ?>
          <button type="button" class="close" data-dismiss="alert"><span>&times;</span></button>
        </div>
      <?php endif; ?>

      <?php if (session()->getFlashdata('error')): ?>
        <div class="alert alert-danger alert-dismissible fade show shadow-sm" role="alert">
          <i class="fas fa-exclamation-circle mr-2"></i> <?= session()->getFlashdata('error') ?>
          <button type="button" class="close" data-dismiss="alert"><span>&times;</span></button>
        </div>
      <?php endif; ?>

      <form id="companySettingsForm" action="<?= base_url('admin/company_settings/update') ?>" method="POST" enctype="multipart/form-data">
        <?= csrf_field() ?>

        <div class="row">

          <!-- Left Column: Company Profile & Statutory -->
          <div class="col-lg-7">

            <!-- Card 1: Brand & Profile -->
            <div class="card card-outline card-primary shadow-sm border-0 mb-4" style="border-radius: 12px;">
              <div class="card-header bg-white pt-3 border-bottom-0">
                <h5 class="card-title font-weight-bold text-dark m-0">
                  <i class="fas fa-id-card text-primary mr-2"></i> Company Profile & Identity
                </h5>
              </div>
              <div class="card-body">
                <div class="form-group">
                  <label class="font-weight-bold text-secondary small">Company Full Legal Name <span class="text-danger">*</span></label>
                  <input type="text" name="company_name" class="form-control" value="<?= esc($settings['company_name'] ?? 'Bloom Solutions') ?>" required placeholder="e.g. Bloom Solutions Private Limited">
                </div>

                <div class="row">
                  <div class="col-md-6 form-group">
                    <label class="font-weight-bold text-secondary small">Brand Name (Primary Word)</label>
                    <input type="text" name="brand_title_primary" class="form-control" value="<?= esc($settings['brand_title_primary'] ?? 'Bloom') ?>" placeholder="e.g. Bloom">
                    <small class="text-muted">Displays in blue on header logos & payslips</small>
                  </div>
                  <div class="col-md-6 form-group">
                    <label class="font-weight-bold text-secondary small">Brand Name (Secondary Word)</label>
                    <input type="text" name="brand_title_secondary" class="form-control" value="<?= esc($settings['brand_title_secondary'] ?? 'Solutions') ?>" placeholder="e.g. Solutions">
                    <small class="text-muted">Displays in accent color on header logos & payslips</small>
                  </div>
                </div>

                <div class="form-group">
                  <label class="font-weight-bold text-secondary small">Registered Corporate Address <span class="text-danger">*</span></label>
                  <textarea name="company_address" class="form-control" rows="2" required placeholder="Full registered office address"><?= esc($settings['company_address'] ?? '') ?></textarea>
                  <small class="text-muted">This address appears on official payslips and exported reports.</small>
                </div>

                <div class="row">
                  <div class="col-md-4 form-group">
                    <label class="font-weight-bold text-secondary small">City</label>
                    <input type="text" name="city" class="form-control" value="<?= esc($settings['city'] ?? 'Hyderabad') ?>" placeholder="Hyderabad">
                  </div>
                  <div class="col-md-4 form-group">
                    <label class="font-weight-bold text-secondary small">State</label>
                    <input type="text" name="state" class="form-control" value="<?= esc($settings['state'] ?? 'Telangana') ?>" placeholder="Telangana">
                  </div>
                  <div class="col-md-4 form-group">
                    <label class="font-weight-bold text-secondary small">Pincode</label>
                    <input type="text" name="pincode" class="form-control" value="<?= esc($settings['pincode'] ?? '500004') ?>" placeholder="500004">
                  </div>
                </div>

                <div class="row">
                  <div class="col-md-4 form-group">
                    <label class="font-weight-bold text-secondary small">Official Email</label>
                    <input type="email" name="email" class="form-control" value="<?= esc($settings['email'] ?? '') ?>" placeholder="hr@bloomsolutions.com">
                  </div>
                  <div class="col-md-4 form-group">
                    <label class="font-weight-bold text-secondary small">Contact Phone</label>
                    <input type="text" name="phone" class="form-control" value="<?= esc($settings['phone'] ?? '') ?>" placeholder="+91 40 1234 5678">
                  </div>
                  <div class="col-md-4 form-group">
                    <label class="font-weight-bold text-secondary small">Official Website</label>
                    <input type="url" name="website" class="form-control" value="<?= esc($settings['website'] ?? '') ?>" placeholder="https://bloomsolutions.com">
                  </div>
                </div>

                <!-- Branding Assets Preview & Upload -->
                <div class="row mt-2 pt-2 border-top">
                  <div class="col-md-6 form-group">
                    <label class="font-weight-bold text-secondary small d-block">Company Logo Image</label>
                    <div class="d-flex align-items-center mb-2">
                      <img src="<?= base_url($settings['logo_url'] ?? 'public/dist/img/bloom.jpg') ?>" alt="Logo" class="img-thumbnail mr-3 shadow-sm" style="height: 52px; width: 52px; object-fit: contain;">
                      <div class="small text-muted">Active Logo: <code><?= esc($settings['logo_url'] ?? 'bloom.jpg') ?></code></div>
                    </div>
                    <input type="file" name="logo_file" class="form-control-file small" accept="image/*">
                    <small class="text-muted d-block mt-1">Recommended size: 200x200px (PNG/JPG)</small>
                  </div>

                  <div class="col-md-6 form-group">
                    <label class="font-weight-bold text-secondary small d-block">Payslip Watermark Image</label>
                    <div class="d-flex align-items-center mb-2">
                      <img src="<?= base_url($settings['watermark_url'] ?? 'public/dist/img/bloom.jpg') ?>" alt="Watermark" class="img-thumbnail mr-3 shadow-sm" style="height: 52px; width: 52px; object-fit: contain; opacity: 0.7;">
                      <div class="small text-muted">Active Watermark: <code><?= esc($settings['watermark_url'] ?? 'bloom.jpg') ?></code></div>
                    </div>
                    <input type="file" name="watermark_file" class="form-control-file small" accept="image/*">
                    <small class="text-muted d-block mt-1">Translucent watermark on payslip background</small>
                  </div>
                </div>

              </div>
            </div>

            <!-- Card 2: Statutory & Registrations -->
            <div class="card card-outline card-info shadow-sm border-0 mb-4" style="border-radius: 12px;">
              <div class="card-header bg-white pt-3 border-bottom-0">
                <h5 class="card-title font-weight-bold text-dark m-0">
                  <i class="fas fa-landmark text-info mr-2"></i> Statutory & Tax Identifiers
                </h5>
              </div>
              <div class="card-body">
                <div class="row">
                  <div class="col-md-6 form-group">
                    <label class="font-weight-bold text-secondary small">Company PAN</label>
                    <input type="text" name="pan_number" class="form-control font-weight-bold" value="<?= esc($settings['pan_number'] ?? '') ?>" placeholder="e.g. AAACB1234F" style="letter-spacing: 1px;">
                  </div>
                  <div class="col-md-6 form-group">
                    <label class="font-weight-bold text-secondary small">Company TAN</label>
                    <input type="text" name="tan_number" class="form-control font-weight-bold" value="<?= esc($settings['tan_number'] ?? '') ?>" placeholder="e.g. HYDB12345A" style="letter-spacing: 1px;">
                  </div>
                </div>

                <div class="row">
                  <div class="col-md-6 form-group">
                    <label class="font-weight-bold text-secondary small">GSTIN</label>
                    <input type="text" name="gstin" class="form-control font-weight-bold" value="<?= esc($settings['gstin'] ?? '') ?>" placeholder="e.g. 36AAACB1234F1Z5" style="letter-spacing: 1px;">
                  </div>
                  <div class="col-md-6 form-group">
                    <label class="font-weight-bold text-secondary small">Corporate CIN</label>
                    <input type="text" name="cin" class="form-control font-weight-bold" value="<?= esc($settings['cin'] ?? '') ?>" placeholder="e.g. U72200TG2020PTC123456" style="letter-spacing: 1px;">
                  </div>
                </div>

                <div class="row">
                  <div class="col-md-6 form-group">
                    <label class="font-weight-bold text-secondary small">EPF Establishment Code</label>
                    <input type="text" name="pf_establishment_code" class="form-control font-weight-bold" value="<?= esc($settings['pf_establishment_code'] ?? '') ?>" placeholder="e.g. AP/HYD/0012345/000">
                  </div>
                  <div class="col-md-6 form-group">
                    <label class="font-weight-bold text-secondary small">ESIC Registration Code</label>
                    <input type="text" name="esic_code" class="form-control font-weight-bold" value="<?= esc($settings['esic_code'] ?? '') ?>" placeholder="e.g. 52000123450001001">
                  </div>
                </div>
              </div>
            </div>

          </div>

          <!-- Right Column: Payroll Cutoff Rules & Payslip Options -->
          <div class="col-lg-5">

            <!-- Card 3: Payroll Cycle Cutoff Rules -->
            <div class="card card-outline card-success shadow-sm border-0 mb-4" style="border-radius: 12px;">
              <div class="card-header bg-white pt-3 border-bottom-0">
                <h5 class="card-title font-weight-bold text-dark m-0">
                  <i class="fas fa-calendar-alt text-success mr-2"></i> Payroll Cycle & Cut-off Rules
                </h5>
              </div>
              <div class="card-body">
                <p class="small text-muted mb-3">
                  Define the monthly attendance cut-off window. The payroll cycle generator and attendance tally modules use these day settings dynamically.
                </p>

                <div class="row align-items-center">
                  <div class="col-sm-6 form-group">
                    <label class="font-weight-bold text-secondary small">Cycle Start Day <span class="text-danger">*</span></label>
                    <div class="input-group">
                      <input type="number" id="cycleStartDayInput" name="payroll_cycle_start_day" class="form-control font-weight-bold text-center" min="1" max="31" value="<?= (int)($settings['payroll_cycle_start_day'] ?? 25) ?>" required>
                      <div class="input-group-append">
                        <span class="input-group-text small">th</span>
                      </div>
                    </div>
                    <small class="text-muted">Day of previous month</small>
                  </div>

                  <div class="col-sm-6 form-group">
                    <label class="font-weight-bold text-secondary small">Cycle End Day <span class="text-danger">*</span></label>
                    <div class="input-group">
                      <input type="number" id="cycleEndDayInput" name="payroll_cycle_end_day" class="form-control font-weight-bold text-center" min="1" max="31" value="<?= (int)($settings['payroll_cycle_end_day'] ?? 24) ?>" required>
                      <div class="input-group-append">
                        <span class="input-group-text small">th</span>
                      </div>
                    </div>
                    <small class="text-muted">Day of payroll month</small>
                  </div>
                </div>

                <div class="row">
                  <div class="col-sm-6 form-group">
                    <label class="font-weight-bold text-secondary small">Salary Pay Day <span class="text-danger">*</span></label>
                    <div class="input-group">
                      <input type="number" id="payDayInput" name="salary_pay_day" class="form-control font-weight-bold text-center" min="1" max="31" value="<?= (int)($settings['salary_pay_day'] ?? 1) ?>" required>
                      <div class="input-group-append">
                        <span class="input-group-text small">st/th</span>
                      </div>
                    </div>
                    <small class="text-muted">Monthly disbursement date</small>
                  </div>

                  <div class="col-sm-6 form-group">
                    <label class="font-weight-bold text-secondary small">Standard Daily Shift</label>
                    <div class="input-group">
                      <input type="number" step="0.5" name="standard_work_hours_per_day" class="form-control text-center font-weight-bold" min="4" max="24" value="<?= (float)($settings['standard_work_hours_per_day'] ?? 9.00) ?>">
                      <div class="input-group-append">
                        <span class="input-group-text small">hrs</span>
                      </div>
                    </div>
                    <small class="text-muted">Daily working hours base</small>
                  </div>
                </div>

                <!-- Dynamic Cut-off Preview Banner -->
                <div class="p-3 bg-light rounded mt-2 border">
                  <div class="font-weight-bold text-primary mb-1 small">
                    <i class="fas fa-info-circle mr-1"></i> Configured Cycle Example Preview:
                  </div>
                  <div class="text-dark small" id="cyclePreviewText">
                    Attendance Window: <strong>25 Aug</strong> to <strong>24 Sep</strong><br>
                    Salary Disbursed On: <strong>01 Oct</strong>
                  </div>
                </div>

              </div>
            </div>

            <!-- Card 4: Payslip Template Settings -->
            <div class="card card-outline card-warning shadow-sm border-0 mb-4" style="border-radius: 12px;">
              <div class="card-header bg-white pt-3 border-bottom-0">
                <h5 class="card-title font-weight-bold text-dark m-0">
                  <i class="fas fa-file-invoice-dollar text-warning mr-2"></i> Payslip Formatting & Disclaimer
                </h5>
              </div>
              <div class="card-body">
                <div class="form-group">
                  <label class="font-weight-bold text-secondary small">Payslip Reference Number Prefix</label>
                  <input type="text" name="payslip_prefix" class="form-control font-weight-bold" value="<?= esc($settings['payslip_prefix'] ?? 'PS-') ?>" placeholder="PS-">
                  <small class="text-muted">Example output: <code>PS-202610-BS00001</code></small>
                </div>

                <div class="form-group">
                  <label class="font-weight-bold text-secondary small">Authorized Signatory Title</label>
                  <input type="text" name="payslip_signatory_title" class="form-control" value="<?= esc($settings['payslip_signatory_title'] ?? 'Authorized Signatory') ?>" placeholder="Authorized Signatory">
                </div>

                <div class="form-group">
                  <label class="font-weight-bold text-secondary small">Computer-Generated Disclaimer Text</label>
                  <textarea name="payslip_footer_disclaimer" class="form-control" rows="3" placeholder="Disclaimer note shown at the bottom of payslips"><?= esc($settings['payslip_footer_disclaimer'] ?? 'This is a computer-generated statement, and does not require a signature and stamp.') ?></textarea>
                  <small class="text-muted">Displayed with green verified badge at the bottom of official employee payslips.</small>
                </div>
              </div>
            </div>

            <!-- Submission Button Card -->
            <div class="card bg-white shadow-sm border-0 p-3 text-right" style="border-radius: 12px;">
              <div>
                <a href="<?= base_url('admin/payroll') ?>" class="btn btn-outline-secondary font-weight-bold mr-2">Cancel</a>
                <button type="submit" class="btn btn-primary font-weight-bold px-4 shadow-sm" style="background: #4a00e0; border-color: #4a00e0;">
                  <i class="fas fa-save mr-2"></i> Save Company Settings
                </button>
              </div>
            </div>

          </div>

        </div>
      </form>

    </div>
  </section>
</div>

<script src="https://cdn.jsdelivr.net/npm/jquery@3.6.0/dist/jquery.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/bootstrap@4.6.1/dist/js/bootstrap.bundle.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/admin-lte@3.2/dist/js/adminlte.min.js"></script>
<script src="https://cdn.datatables.net/1.13.6/js/jquery.dataTables.min.js"></script>
<script src="https://cdn.datatables.net/1.13.6/js/dataTables.bootstrap4.min.js"></script>

<script>
  document.addEventListener('DOMContentLoaded', function () {
    const startInput = document.getElementById('cycleStartDayInput');
    const endInput   = document.getElementById('cycleEndDayInput');
    const payInput   = document.getElementById('payDayInput');
    const previewEl  = document.getElementById('cyclePreviewText');

    function updatePreview() {
      const s = parseInt(startInput.value) || 25;
      const e = parseInt(endInput.value) || 24;
      const p = parseInt(payInput.value) || 1;

      previewEl.innerHTML = `Attendance Window: <strong>${s}th of previous month</strong> to <strong>${e}th of payroll month</strong><br>` +
                            `Scheduled Pay Date: <strong>${p}st/th of payout month</strong>`;
    }

    startInput.addEventListener('input', updatePreview);
    endInput.addEventListener('input', updatePreview);
    payInput.addEventListener('input', updatePreview);
    updatePreview();
  });
</script>



</body></html>
