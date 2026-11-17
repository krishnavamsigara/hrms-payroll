<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Bloom Solutions | Designations</title>
  
  <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@300;400;600;700&display=swap" rel="stylesheet">
  <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/5.15.4/css/all.min.css">
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/admin-lte@3.2/dist/css/adminlte.min.css">

  <link rel="stylesheet" href="https://cdn.datatables.net/1.13.6/css/dataTables.bootstrap4.min.css">

  <style>
    :root { 
        --bloom-purple: #4a00e0; 
        --soft-gray: #f8fafc; 
        --border-color: #e2e8f0; 
    }

    body { 
        font-family: 'Plus Jakarta Sans', sans-serif; 
        background-color: var(--soft-gray); 
        font-size: 13px; 
        color: #334155;
    }

    .main-header {
      border-bottom: 1px solid #e2e8f0 !important;
      background: #ffffff !important;
      height: 55px;
    }

    .main-sidebar {
      background: #111c43 !important;
    }

    .card-bloom { 
        border: 1px solid var(--border-color) !important; 
        border-radius: 20px !important; 
        background: #fff; 
        box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.04); 
        overflow: hidden;
    }

    .table thead th { 
        border-top: none; 
        border-bottom: 1px solid var(--border-color); 
        letter-spacing: 0.5px; 
        padding: 10px 15px;
    }
    .table td { vertical-align: middle !important; padding: 15px; border-top: 1px solid #f1f5f9; }
    
    .desg-icon {
        width: 38px;
        height: 38px;
        border-radius: 10px;
        background: #f0f7ff;
        color: var(--bloom-purple);
        display: flex;
        align-items: center;
        justify-content: center;
        font-size: 15px;
    }

    .search-input {
        border-radius: 12px;
        border: 1px solid var(--border-color);
        padding-left: 35px;
        transition: 0.3s;
    }
    .search-input:focus {
        border-color: var(--bloom-purple);
        box-shadow: 0 0 0 4px rgba(74, 0, 224, 0.05);
    }

    .badge-status-active {
        background-color: #e6f4ea;
        color: #137333;
        font-weight: 600;
        padding: 4px 10px;
        border-radius: 12px;
        font-size: 11px;
        min-width: 90px;
        height: 28px;
    }

    .badge-status-inactive {
    background-color: #fff4e5;
    color: #c2410c;
    font-weight: 600;
    padding: 4px 10px;
    border-radius: 12px;
    font-size: 11px;
    min-width: 90px;
    height: 28px;
}

    .modal-content {
        border-radius: 16px;
        border: none;
        box-shadow: 0 10px 25px rgba(0,0,0,0.1);
    }
    .modal-header {
        border-bottom: 1px solid var(--border-color);
        background: #f8fafc;
        border-top-left-radius: 16px;
        border-top-right-radius: 16px;
    }

    /* Bloom Theme - Department Modals */

.modal-content {
    border-radius: 16px;
    border: 1px solid var(--border-color);
    box-shadow: 0 15px 40px rgba(18, 0, 56, 0.15);
    overflow: hidden;
}

.modal-header {
    background: #ffffff;
    border-bottom: 1px solid var(--border-color);
    padding: 16px 20px;
}

.modal-title {
    color: #1e293b !important;
    font-size: 16px;
    font-weight: 700;
}

.modal-title i {
    color: var(--bloom-purple) !important;
}

.modal-header .close {
    color: #64748b;
    opacity: 0.8;
}

.modal-header .close:hover {
    color: var(--bloom-purple);
    opacity: 1;
}

.modal-body {
    background: #ffffff;
}

.modal-body label {
    color: #475569 !important;
    font-size: 11px;
    font-weight: 800 !important;
    letter-spacing: 0.4px;
}

.modal-body .form-control {
    border: 1px solid var(--border-color);
    border-radius: 10px;
    color: #334155;
    font-size: 13px;
    font-weight: 500;
    transition: all 0.2s ease;
}

.modal-body .form-control:focus {
    border-color: var(--bloom-purple);
    box-shadow: 0 0 0 3px rgba(74, 0, 224, 0.10);
    outline: none;
}

.modal-body .form-control::placeholder {
    color: #94a3b8;
}

.modal-footer {
    background: #f8fafc !important;
    border-top: 1px solid var(--border-color) !important;
    padding: 14px 20px;
}

.modal-footer .btn-secondary {
    background: #ffffff;
    color: #64748b;
    border: 1px solid var(--border-color);
    border-radius: 10px !important;
    font-size: 12px;
    font-weight: 700;
}

.modal-footer .btn-secondary:hover {
    background: #f8fafc;
    color: #334155;
    border-color: #cbd5e1;
}

.modal-footer .btn-primary {
    background: linear-gradient(135deg, #4a00e0 0%, #2a0080 100%) !important;
    color: #ffffff;
    border: none !important;
    border-radius: 10px !important;
    font-size: 12px;
    font-weight: 700;
    transition: all 0.2s ease;
}

.modal-footer .btn-primary:hover {
    background: linear-gradient(135deg, #2a0080 0%, #4a00e0 100%) !important;
    color: #ffffff;
    transform: translateY(-1px);
    box-shadow: 0 4px 10px rgba(74, 0, 224, 0.25);
}

/* Pagination Styling */
.dataTables_paginate .paginate_button {
    margin: 0 3px !important;
}

.dataTables_paginate .paginate_button .page-link,
.dataTables_paginate .page-link {
    border-radius: 10px !important;
    border: 1px solid #e2e8f0 !important;
    color: #64748b !important;
    font-weight: 600;
}

/* Active Page */
.dataTables_paginate .page-item.active .page-link {
    background: linear-gradient(135deg, #4a00e0 0%, #2a0080 100%) !important;
    border-color: #4a00e0 !important;
    color: #fff !important;
}

/* Hover */
.dataTables_paginate .page-link:hover {
    background: #f8faff !important;
    color: #4a00e0 !important;
    border-color: #4a00e0 !important;
}

/* Info Text */
.dataTables_info {
    color: #64748b !important;
    font-size: 12px;
    font-weight: 600;
    padding-left: 15px;
}
.dataTables_length {
    margin: 8px 15px !important;
    font-size: 13px;
    font-weight: 600;
    color: #64748b;
}

.dataTables_length select {
    height: 34px !important;
    min-width: 65px;
    border: 1px solid #e2e8f0 !important;
    border-radius: 10px !important;   /* Less rounded */
    padding: 4px 8px !important;
}


.dataTables_paginate {
    padding-right: 15px;
}

/* Keep Show Entries and Search on same row */
.dataTables_wrapper .dataTables_length {
    float: left;
    margin: 8px 15px !important;
}

.dataTables_wrapper .dataTables_filter {
    float: right;
    margin: 15px;
    text-align: right;
}

.dataTables_wrapper .row:first-child {
    display: flex;
    justify-content: space-between;
    align-items: center;
}

.dataTables_wrapper .dataTables_filter input {
    border: 1px solid #e2e8f0;
    border-radius: 10px;
    padding: 6px 10px;
    margin-left: 5px;
}

/* Sorting arrows */
table.dataTable thead .sorting:before,
table.dataTable thead .sorting:after,
table.dataTable thead .sorting_asc:before,
table.dataTable thead .sorting_asc:after,
table.dataTable thead .sorting_desc:before,
table.dataTable thead .sorting_desc:after {
    top: 50% !important;
    transform: translateY(-50%);
    font-size: 10px !important;
    color: #4a00e0 !important;
}

  </style>
</head>

<body class="hold-transition sidebar-mini layout-fixed layout-navbar-fixed layout-footer-fixed">
<div class="wrapper">

   <div class="content-wrapper p-4">
    
    <div class="d-flex justify-content-between align-items-center mb-4">
      <div>
        <h4 class="font-weight-bold mb-0">Designations</h4>
        <small class="text-muted">Manage your organization's job titles and roles</small>
      </div>
      <button class="btn btn-primary rounded-pill px-4" style="background:var(--bloom-purple); border:none;" data-toggle="modal" data-target="#addDesgModal">
        <i class="fas fa-plus mr-2"></i> Add Designation
      </button>
    </div>

    <!-- Alert container -->
    <div id="alertContainer"></div>

    <div class="card-bloom">
      <!-- <div class="p-3 border-bottom position-relative d-flex justify-content-between align-items-center"> -->
        <!-- <div class="position-relative w-25">
            <i class="fas fa-search position-absolute" style="left: 12px; top: 10px; color: #94a3b8;"></i>
            <input type="text" id="desgSearch" class="form-control form-control-sm search-input" placeholder="Search designations...">
        </div>
        <small class="text-muted font-weight-bold">Total Designations: <?= count($designations ?? []) ?></small>
      </div> -->

      <div class="table-responsive">
        <table class="table table-hover mb-0" id="designation">
          <thead class="bg-light">
            <tr class="small text-uppercase text-muted">
              <th class="pl-4">ID</th>
              <th>Designation Name</th>
              <th>Status</th>
              <th class="text-right pr-4">Action</th>
            </tr>
          </thead>
          <tbody id="desgTableBody">
          <?php if (!empty($designations)): ?>
              <?php foreach ($designations as $row): ?>
                  <tr class="desg-row" id="row-desg-<?= esc($row['designation_id']) ?>">
                      <td class="pl-4 font-weight-bold text-muted"><?= esc($row['designation_id']) ?></td>
                      <td>
                          <div class="d-flex align-items-center">
                              <!-- <div class="desg-icon mr-3">
                                  <i class="fas fa-id-badge"></i>
                              </div> -->
                              <div>
                                  <strong class="desg-title text-dark">
                                      <?= esc($row['designation_name']) ?>
                                  </strong>
                              </div>
                          </div>
                      </td>

                      <td>
                          <?php if (($row['status'] ?? '1') == '1'): ?>
                              <span class="badge-status-active"><i class="fas fa-check-circle mr-1"></i> Active</span>
                          <?php else: ?>
                              <span class="badge-status-inactive"><i class="fas fa-times-circle mr-1"></i> Inactive</span>
                          <?php endif; ?>
                      </td>

                      <td class="text-right pr-4">
                          <button class="btn btn-sm btn-outline-primary rounded-pill px-3 mr-1 btn-edit-desg"
                                  data-id="<?= esc($row['designation_id']) ?>"
                                  data-name="<?= esc($row['designation_name']) ?>"
                                  data-status="<?= esc($row['status'] ?? '1') ?>">
                              <i class="fas fa-edit mr-1"></i> Edit
                          </button>
                          <button class="btn btn-sm btn-outline-danger rounded-pill px-3 btn-delete-desg"
                                  data-id="<?= esc($row['designation_id']) ?>"
                                  data-name="<?= esc($row['designation_name']) ?>">
                              <i class="fas fa-trash-alt mr-1"></i> Delete
                          </button>
                      </td>
                  </tr>
              <?php endforeach; ?>
          <?php else: ?>
              <tr>
                  <td colspan="4" class="text-center py-4 text-muted">
                      No designations found.
                  </td>
              </tr>
          <?php endif; ?>
          </tbody>
        </table>
      </div>
    </div>

  </div>
</div>

<!-- ADD DESIGNATION MODAL -->
<div class="modal fade" id="addDesgModal" tabindex="-1" role="dialog" aria-hidden="true">
  <div class="modal-dialog modal-dialog-centered" role="document">
    <div class="modal-content">
      <div class="modal-header">
        <h5 class="modal-title font-weight-bold text-dark"><i class="fas fa-id-badge text-primary mr-2"></i> Add Designation</h5>
        <button type="button" class="close" data-dismiss="modal" aria-label="Close">
          <span aria-hidden="true">&times;</span>
        </button>
      </div>
      <form id="addDesgForm">
        <div class="modal-body p-4">
          <input type="hidden" name="mode" value="INSERT">
          <div class="form-group">
            <label class="font-weight-bold text-muted small">DESIGNATION NAME <span class="text-danger">*</span></label>
            <input type="text" name="designation_name" class="form-control form-control-lg" placeholder="e.g. Senior Software Engineer" required>
          </div>
          <div class="form-group mb-0">
            <label class="font-weight-bold text-muted small">STATUS</label>
            <select name="status" class="form-control">
              <option value="1" selected>Active</option>
              <option value="0">Inactive</option>
            </select>
          </div>
        </div>
        <div class="modal-footer bg-light border-0">
          <button type="button" class="btn btn-secondary rounded-pill px-4" data-dismiss="modal">Cancel</button>
          <button type="submit" class="btn btn-primary rounded-pill px-4" style="background:var(--bloom-purple); border:none;">
            <i class="fas fa-save mr-1"></i> Save Designation
          </button>
        </div>
      </form>
    </div>
  </div>
</div>

<!-- EDIT DESIGNATION MODAL -->
<div class="modal fade" id="editDesgModal" tabindex="-1" role="dialog" aria-hidden="true">
  <div class="modal-dialog modal-dialog-centered" role="document">
    <div class="modal-content">
      <div class="modal-header">
        <h5 class="modal-title font-weight-bold text-dark"><i class="fas fa-edit text-primary mr-2"></i> Edit Designation</h5>
        <button type="button" class="close" data-dismiss="modal" aria-label="Close">
          <span aria-hidden="true">&times;</span>
        </button>
      </div>
      <form id="editDesgForm">
        <div class="modal-body p-4">
          <input type="hidden" name="mode" value="UPDATE">
          <input type="hidden" name="designation_id" id="editDesgId">
          <div class="form-group">
            <label class="font-weight-bold text-muted small">DESIGNATION NAME <span class="text-danger">*</span></label>
            <input type="text" name="designation_name" id="editDesgName" class="form-control form-control-lg" required>
          </div>
          <div class="form-group mb-0">
            <label class="font-weight-bold text-muted small">STATUS</label>
            <select name="status" id="editDesgStatus" class="form-control">
              <option value="1">Active</option>
              <option value="0">Inactive</option>
            </select>
          </div>
        </div>
        <div class="modal-footer bg-light border-0">
          <button type="button" class="btn btn-secondary rounded-pill px-4" data-dismiss="modal">Cancel</button>
          <button type="submit" class="btn btn-primary rounded-pill px-4" style="background:var(--bloom-purple); border:none;">
            <i class="fas fa-check-circle mr-1"></i> Update Designation
          </button>
        </div>
      </form>
    </div>
  </div>
</div>

<!-- DELETE CONFIRMATION MODAL -->
<div class="modal fade" id="deleteDesgModal" tabindex="-1" role="dialog" aria-hidden="true">
  <div class="modal-dialog modal-dialog-centered modal-sm" role="document">
    <div class="modal-content">
      <div class="modal-header border-0 pb-0">
        <button type="button" class="close" data-dismiss="modal" aria-label="Close">
          <span aria-hidden="true">&times;</span>
        </button>
      </div>
      <form id="deleteDesgForm">
        <div class="modal-body text-center pt-0 px-4">
          <input type="hidden" name="mode" value="DELETE">
          <input type="hidden" name="designation_id" id="deleteDesgId">
          <div class="text-danger mb-3" style="font-size: 40px;">
            <i class="fas fa-exclamation-circle"></i>
          </div>
          <h5 class="font-weight-bold">Are you sure?</h5>
          <p class="text-muted small">Do you really want to delete designation <strong id="deleteDesgName" class="text-dark"></strong>?</p>
        </div>
        <div class="modal-footer border-0 justify-content-center pt-0 pb-4">
          <button type="button" class="btn btn-light rounded-pill px-4" data-dismiss="modal">Cancel</button>
          <button type="submit" class="btn btn-danger rounded-pill px-4">Delete</button>
        </div>
      </form>
    </div>
  </div>
</div>

<script src="https://cdn.jsdelivr.net/npm/jquery@3.6.0/dist/jquery.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/bootstrap@4.6.1/dist/js/bootstrap.bundle.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/admin-lte@3.2/dist/js/adminlte.min.js"></script>

 <script src="https://cdn.datatables.net/1.13.6/js/jquery.dataTables.min.js"></script>
  <script src="https://cdn.datatables.net/1.13.6/js/dataTables.bootstrap4.min.js"></script>

<script>
    $(document).ready(function () {
    $('#designation').DataTable({
      responsive: true,
      paging: true,
      ordering: true,
      order: [], // Use backend order initially
      searching: true,
      info: true,
      lengthChange: true,
      pageLength:10,
      dom: "<'row'<'col-md-6'l><'col-md-6'f>>" +
         "t" +
         "<'row'<'col-md-6'i><'col-md-6'p>>"

      });
});

$(document).ready(function(){
  // Search filter
  $("#desgSearch").on("keyup", function() {
    var value = $(this).val().toLowerCase();
    $("#desgTableBody .desg-row").filter(function() {
      $(this).toggle($(this).find(".desg-title").text().toLowerCase().indexOf(value) > -1)
    });
  });

  function showAlert(type, message) {
    var alertHtml = '<div class="alert alert-' + type + ' alert-dismissible fade show rounded-lg shadow-sm" role="alert">' +
      '<strong>' + (type === 'success' ? 'Success!' : 'Error!') + '</strong> ' + message +
      '<button type="button" class="close" data-dismiss="alert" aria-label="Close">' +
      '<span aria-hidden="true">&times;</span></button></div>';
    $('#alertContainer').html(alertHtml);
    setTimeout(function() { $('.alert').alert('close'); }, 4000);
  }

  // Submit Add Designation
  $('#addDesgForm').on('submit', function(e){
    e.preventDefault();
    $.ajax({
      url: '<?= base_url("admin/save_designation") ?>',
      type: 'POST',
      data: $(this).serialize(),
      dataType: 'json',
      success: function(res) {
        if (res.status === 'success') {
          $('#addDesgModal').modal('hide');
          $('#addDesgForm')[0].reset();
          showAlert('success', res.message);
          setTimeout(function(){ location.reload(); }, 800);
        } else {
          showAlert('danger', res.message);
        }
      },
      error: function() {
        showAlert('danger', 'Failed to communicate with server.');
      }
    });
  });

  // Open Edit Modal
  $(document).on('click', '.btn-edit-desg', function(){
    var id = $(this).data('id');
    var name = $(this).data('name');
    var status = $(this).data('status');

    $('#editDesgId').val(id);
    $('#editDesgName').val(name);
    $('#editDesgStatus').val(status);
    $('#editDesgModal').modal('show');
  });

  // Submit Edit Designation
  $('#editDesgForm').on('submit', function(e){
    e.preventDefault();
    $.ajax({
      url: '<?= base_url("admin/save_designation") ?>',
      type: 'POST',
      data: $(this).serialize(),
      dataType: 'json',
      success: function(res) {
        if (res.status === 'success') {
          $('#editDesgModal').modal('hide');
          showAlert('success', res.message);
          setTimeout(function(){ location.reload(); }, 800);
        } else {
          showAlert('danger', res.message);
        }
      },
      error: function() {
        showAlert('danger', 'Failed to update designation.');
      }
    });
  });

  // Open Delete Modal
  $(document).on('click', '.btn-delete-desg', function(){
    var id = $(this).data('id');
    var name = $(this).data('name');

    $('#deleteDesgId').val(id);
    $('#deleteDesgName').text(name);
    $('#deleteDesgModal').modal('show');
  });

  // Submit Delete Designation
  $('#deleteDesgForm').on('submit', function(e){
    e.preventDefault();
    $.ajax({
      url: '<?= base_url("admin/save_designation") ?>',
      type: 'POST',
      data: $(this).serialize(),
      dataType: 'json',
      success: function(res) {
        if (res.status === 'success') {
          $('#deleteDesgModal').modal('hide');
          showAlert('success', res.message);
          setTimeout(function(){ location.reload(); }, 800);
        } else {
          showAlert('danger', res.message);
        }
      },
      error: function() {
        showAlert('danger', 'Failed to delete designation.');
      }
    });
  });
});
</script>

</body>
</html>
