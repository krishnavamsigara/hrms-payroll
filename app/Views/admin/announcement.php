
<?php
$session = session();
$original_role = $session->get('user_category');
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title> Bloom Solutions | Announcement</title>
<link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@300;400;600;700&display=swap" rel="stylesheet">
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/5.15.4/css/all.min.css">
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/admin-lte@3.2/dist/css/adminlte.min.css">

<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/toastify-js/src/toastify.min.css">

<style>


/* =========================================
   BLOOM ANNOUNCEMENT CENTER
========================================= */

.announcement-page {
    font-family: 'Plus Jakarta Sans', sans-serif;
    color: #334155;
}

/* Main Header */

.announcement-hero {
    background: linear-gradient(135deg, #111c43, #4a00e0);
    border-radius: 18px;
    padding: 24px;
    color: #fff;
    margin-bottom: 20px;
    box-shadow: 0 8px 20px rgba(74, 0, 224, 0.12);
}

.announcement-hero h4 {
    font-size: 21px;
    font-weight: 700;
    margin-bottom: 6px;
}

.announcement-hero p {
    color: #dbeafe;
    font-size: 13px;
    margin-bottom: 0;
}

.announcement-hero-icon {
    width: 54px;
    height: 54px;
    border-radius: 15px;
    background: rgba(255,255,255,.15);
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 23px;
}

/* Main Content Card */

.announcement-container {
    background: #fff;
    border: 1px solid #e2e8f0;
    border-radius: 18px;
    padding: 20px;
    box-shadow: 0 4px 12px rgba(15,23,42,.04);
}

/* Announcement Item */

.announce-item {
    position: relative;
    display: flex;
    gap: 16px;
    padding: 20px;
    margin-bottom: 14px;
    background: #fff;
    border: 1px solid #e5e7eb;
    border-radius: 15px;
    transition: all .25s ease;
}

.announce-item:last-child {
    margin-bottom: 0;
}

.announce-item:hover {
    border-color: #c4b5fd;
    box-shadow: 0 8px 20px rgba(74,0,224,.08);
    transform: translateY(-2px);
}

/* Icon */

.announce-icon {
    width: 48px;
    height: 48px;
    flex-shrink: 0;
    border-radius: 13px;
    background: linear-gradient(135deg,#ede9fe,#ddd6fe);
    color: #4a00e0;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 19px;
}

/* Title */

.announce-title {
    font-size: 15px;
    font-weight: 700;
    color: #111827;
    line-height: 1.5;
}

/* Date */

.announce-date {
    color: #64748b;
    font-size: 11px;
    font-weight: 500;
    margin-top: 3px;
}

/* Message */

.announce-item p {
    color: #475569;
    font-size: 13px;
    line-height: 1.7;
    margin-top: 12px;
    margin-bottom: 0;
}

/* Category Badge */

.badge-dept {
    display: inline-flex;
    align-items: center;
    background: #ede9fe;
    color: #5b21b6;
    border: 1px solid #ddd6fe;
    border-radius: 8px;
    padding: 5px 10px;
    font-size: 10px;
    font-weight: 700;
    letter-spacing: .3px;
}

/* Action Buttons */

.announce-item .btn-outline-primary,
.announce-item .btn-outline-danger {
    width: 32px;
    height: 32px;
    padding: 0;
    border-radius: 9px !important;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    font-size: 12px;
}

.announce-item .btn-outline-primary {
    color: #4a00e0;
    border-color: #d8b4fe;
}

.announce-item .btn-outline-danger {
    color: #dc2626;
    border-color: #fecaca;
}

.announce-item .btn-outline-primary:hover {
    background: #4a00e0;
    color: #fff;
    border-color: #4a00e0;
}

.announce-item .btn-outline-danger:hover {
    background: #dc2626;
    color: #fff;
    border-color: #dc2626;
}

/* Mobile */

@media (max-width: 576px) {

    .announcement-hero {
        padding: 18px;
    }

    .announcement-hero h4 {
        font-size: 18px;
    }

    .announcement-container {
        padding: 12px;
    }

    .announce-item {
        padding: 14px;
        gap: 11px;
    }

    .announce-icon {
        width: 40px;
        height: 40px;
        font-size: 16px;
    }

    .announce-title {
        font-size: 14px;
    }

    .announce-item .d-flex.justify-content-between {
        flex-wrap: wrap;
        gap: 8px;
    }

    .badge-dept {
        font-size: 9px;
        padding: 4px 8px;
    }
}

.nav-pills .nav-link.active {
    background: #4a00e0 !important;
    color: #fff !important;
}

body{
font-family:'Plus Jakarta Sans',sans-serif;
background:#f8fafc;
font-size:13px;
color:#334155;
}

/* Card */

.card-bloom{
border:1px solid #e2e8f0;
border-radius:14px;
background:#fff;
box-shadow:0 3px 6px rgba(0,0,0,0.05);
padding:15px;
}

/* Announcement Card */

.announce-item{
    background:#fff;
    border:1px solid #e5e7eb;
    border-radius:16px;
    padding:18px;
    margin-bottom:16px;
    display:flex;
    gap:16px;
    transition:.3s;
    box-shadow:0 4px 12px rgba(15,23,42,.05);
}

.announce-item:hover{
    transform:translateY(-3px);
    box-shadow:0 12px 24px rgba(74,0,224,.12);
}
 .nav-pills .nav-link.active{ background:#007bff!important; color:#fff!important; }
.announce-icon{
width:52px;
height:52px;
border-radius:14px;
background:linear-gradient(135deg,#4a00e0,#111c43);
color:#fff;
display:flex;
align-items:center;
justify-content:center;
font-size:20px;
flex-shrink:0;
}

.announce-title{
font-size:17px;
font-weight:700;
color:#111827;
}
.announce-date{
font-size:12px;
color:#6b7280;
font-weight:500;
margin-top:3px;
}

.badge-dept{
background:#ede9fe;
color:#5b21b6;
padding:6px 12px;
border-radius:10px;
font-weight:600;
font-size:12px;
border:1px solid #d8b4fe;
}

/* Bloom Modal */

.modal-content{
    border:0;
    border-radius:18px;
    overflow:hidden;
    box-shadow:0 15px 40px rgba(17,28,67,.15);
}

.modal-header{
    background:linear-gradient(135deg,#111c43,#4a00e0);
    color:#fff;
    border-bottom:0;
    padding:18px 22px;
}

.modal-header .close{
    color:#fff;
    opacity:1;
    text-shadow:none;
}

.modal-title{
    font-weight:700;
    font-size:18px;
}

.modal-body{
    padding:22px;
    background:#fff;
}

.modal-footer{
    border-top:1px solid #eef2f7;
    padding:16px 22px;
    background:#fafcff;
}

.modal .form-group label{
    font-weight:600;
    color:#334155;
}

.modal .form-control,
.modal .custom-select{
    border:1px solid #dbe3ef;
    border-radius:10px;
    height:42px;
    box-shadow:none;
}

.modal textarea.form-control{
    min-height:110px;
    resize:none;
}

.modal .form-control:focus,
.modal .custom-select:focus{
    border-color:#4a00e0;
    box-shadow:0 0 0 .15rem rgba(74,0,224,.12);
}

.modal .btn-primary{
    background:#4a00e0;
    border-color:#4a00e0;
    border-radius:10px;
    padding:8px 18px;
}

.modal .btn-secondary{
    border-radius:10px;
    padding:8px 18px;
}
.btn-primary{
    background:linear-gradient(135deg,#111c43,#4a00e0);
    border:none;
    border-radius:10px;
    padding:8px 18px;
    font-weight:600;
}

.btn-primary:hover{
    background:linear-gradient(135deg,#4a00e0,#111c43);
}

.announce-item p{
    color:#475569;
    font-size:14px;
    margin-top:12px;
    line-height:1.7;
}
.btn-outline-primary,
.btn-outline-danger{
    border-radius:10px;
    width:36px;
    height:36px;
    padding:0;
}

.btn-outline-primary:hover{
    background:#4a00e0;
    border-color:#4a00e0;
}

.btn-outline-danger:hover{
    background:#ef4444;
    border-color:#ef4444;
}

</style>



<!-- Content -->
<div class="content-wrapper">
<section class="content p-3">


<div class="announcement-page">

    <!-- Announcement Hero -->

    <div class="announcement-hero">

        <div class="d-flex align-items-center">

            <div class="announcement-hero-icon mr-3">
                <i class="fas fa-bullhorn"></i>
            </div>

            <div>
                <h4>Announcement Center</h4>
                <p>
                    Stay updated with the latest news and important notices.
                </p>
            </div>

        </div>

    </div>


    <!-- Announcement Container -->

    <div class="announcement-container">

        <div class="d-flex justify-content-between align-items-center mb-4">

            <div>
                <h6 class="font-weight-bold mb-1">
                    <i class="fas fa-bell text-primary mr-1"></i>
                    Latest Announcements
                </h6>

                <small class="text-muted">
                    Company updates and important information
                </small>
            </div>

            <?php if (in_array($original_role, ['ADMIN', 'HR'])): ?>

                <button class="btn btn-primary btn-sm"
                        data-toggle="modal"
                        data-target="#announcementModal">

                    <i class="fas fa-plus mr-1"></i>
                    Add Announcement

                </button>

            <?php endif; ?>

        </div>


        <div id="announcementList">

            <?php if(!empty($announcement) && $announcement[0]['status'] != 'N') : ?>

                <?php foreach($announcement as $row): ?>

                    <div class="announce-item">

                        <!-- Announcement Icon -->

                        <div class="announce-icon">
                            <i class="fas fa-bullhorn"></i>
                        </div>


                        <div style="flex:1; min-width:0;">

                            <!-- Title + Category -->

                            <div class="d-flex justify-content-between align-items-center">

                                <div class="announce-title">
                                    <?= esc($row['Title']) ?>
                                </div>

                                <span class="badge-dept ml-2">
                                    <?= esc($row['UserCategory']) ?>
                                </span>

                            </div>


                            <!-- Date -->

                            <div class="announce-date">

                                <i class="far fa-calendar-alt mr-1"></i>

                                <?= date('d-M-Y', strtotime($row['CreatedOn'])) ?>

                            </div>


                            <!-- Message -->

                            <p>
                                <?= esc($row['Message']) ?>
                            </p>


                            <!-- Bottom Actions -->

                            <div class="d-flex justify-content-between align-items-center mt-3">

                                <small class="text-muted">
                                    <i class="fas fa-user-circle mr-1"></i>
                                    Official Announcement
                                </small>


                                <?php if (in_array($original_role, ['ADMIN', 'HR'])): ?>

                                    <div>

                                        <button
                                            class="btn btn-sm btn-outline-primary mr-1"
                                            title="Edit"
                                            onclick="editAnnouncement(
                                                <?= $row['AnnouncementID'] ?>,
                                                '<?= esc($row['Title'], 'js') ?>',
                                                '<?= esc($row['UserCategory'], 'js') ?>',
                                                '<?= esc($row['Message'], 'js') ?>'
                                            )">

                                            <i class="fas fa-edit"></i>

                                        </button>


                                        <button
                                            class="btn btn-sm btn-outline-danger"
                                            title="Delete"
                                            onclick="deleteAnnouncement(
                                                <?= $row['AnnouncementID'] ?>
                                            )">

                                            <i class="fas fa-trash"></i>

                                        </button>

                                    </div>

                                <?php endif; ?>

                            </div>

                        </div>

                    </div>

                <?php endforeach; ?>

            <?php else: ?>

                <div class="text-center py-5">

                    <i class="fas fa-bullhorn fa-3x text-muted mb-3"></i>

                    <h6 class="font-weight-bold text-dark">
                        <?= esc($announcement[0]['remarks'] ?? 'No announcements available') ?>
                    </h6>

                    <p class="text-muted mb-0">
                        There are no announcements to display right now.
                    </p>

                </div>

            <?php endif; ?>

        </div>

    </div>

</div>

<!-- Modal -->

<div class="modal fade" id="announcementModal">

<div class="modal-dialog">

<div class="modal-content">

<div class="modal-header">
<h5 class="modal-title">Announcement</h5>
<button class="close" data-dismiss="modal">&times;</button>
</div>

<div class="modal-body">

<input type="hidden" id="announcement_id">

<div class="form-group">
<label>Title</label>
<input type="text" id="title" class="form-control">
</div>

<div class="form-group">
<label>User Category</label>
<select id="dept" class="form-control">
    <option value="">Select User Category</option>
    <option>ALL</option>
    <option>ADMIN</option>
    <option>MANAGER</option>
    <option>EMP</option>
    <option>HR</option>
    <option>INTERN</option>
</select>
</div>

<!-- <div class="form-group">
<label>Date</label>
<input type="date" id="date" class="form-control">
</div> -->

<div class="form-group">
<label>Message</label>
<textarea id="message" class="form-control" rows="4"></textarea>
</div>

</div>

<div class="modal-footer">

<button class="btn btn-secondary" data-dismiss="modal">Cancel</button>

<button class="btn btn-primary" onclick="saveAnnouncement()">
<i class="fas fa-save"></i> Save
</button>

</div>

</div>
   </div>
    </section>
</div>


<script src="https://cdn.jsdelivr.net/npm/jquery@3.6.0/dist/jquery.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/bootstrap@4.6.1/dist/js/bootstrap.bundle.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/admin-lte@3.2/dist/js/adminlte.min.js"></script>

<script src="https://cdn.jsdelivr.net/npm/toastify-js"></script>
<script>

/* Default Announcements */


function saveAnnouncement(){

    $.ajax({

        url : "<?= base_url('admin/save_announcement') ?>",
        type : "POST",

        data : {

            announcement_id : $("#announcement_id").val(),
            title : $("#title").val(),
            user_category : $("#dept").val(),
            message : $("#message").val()

        },

        success:function(response){
              console.log(response);
    console.log(response.message);

            $('#announcementModal').modal('hide');

            Toastify({
                text: response.message,
                duration:3000,
                gravity:"top",
                position:"right",
                close:true,
                backgroundColor:"linear-gradient(to right,#00b09b,#96c93d)"
            }).showToast();

            setTimeout(function(){
                location.reload();
            },1000);
        }

    });

}

function editAnnouncement(id, title, category, message) {

    $("#announcement_id").val(id);
    $("#title").val(title);
    $("#dept").val(category);
    $("#message").val(message);

    $("#announcementModal").modal("show");
}

function deleteAnnouncement(id){

    deleteId = id;

    $("#deleteModal").modal("show");
}

$(document).on("click", "#confirmDelete", function () {

    $.ajax({

        url : "<?= base_url('admin/delete_announcement') ?>",
        type : "POST",

        data : {
            announcement_id : deleteId
        },

        success:function(response){

            $("#deleteModal").modal("hide");

            Toastify({
                text: response.message,
                duration:3000,
                gravity:"top",
                position:"right",
                close:true,
                backgroundColor:"linear-gradient(to right,#dc3545,#ff6b6b)"
            }).showToast();

            setTimeout(function(){
                location.reload();
            },1000);

        }
    });

});

</script>
<div class="modal fade" id="deleteModal">
    <div class="modal-dialog modal-sm modal-dialog-centered">
        <div class="modal-content">

            <div class="modal-header bg-danger text-white">
                <h5 class="modal-title">
                    <i class="fas fa-trash"></i> Delete Announcement
                </h5>
                <button type="button" class="close text-white" data-dismiss="modal">
                    &times;
                </button>
            </div>

            <div class="modal-body text-center">
                Are you sure you want to delete this announcement?
            </div>

            <div class="modal-footer">
                <button class="btn btn-secondary" data-dismiss="modal">
                    Cancel
                </button>

                <button class="btn btn-danger" id="confirmDelete">
                    Delete
                </button>
            </div>

        </div>
    </div>
      </div>

</body>
</html>

