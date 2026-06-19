#ifndef REGULARSINGERSDIALOG_H
#define REGULARSINGERSDIALOG_H

#include <QDialog>
#include <QSortFilterProxyModel>
#include <QSqlTableModel>
#include "src/models/tablemodelrotation.h"
#include "src/models/tablemodelhistorysingers.h"
#include "settings.h"

namespace Ui {
class DlgRegularSingers;
}

class DlgRegularSingers : public QDialog
{
    Q_OBJECT

private:
    int m_rtClickHistorySingerId;
    Ui::DlgRegularSingers *ui;
    TableModelHistorySingers m_historySingersModel{this};
    ItemDelegateHistorySingers m_historySingersDelegate{this};
    TableModelRotation *m_rotModel;
    Settings m_settings;

public:
    explicit DlgRegularSingers(TableModelRotation *rotationModel, QWidget *parent = 0);
    ~DlgRegularSingers();
    TableModelHistorySingers& historySingersModel() { return m_historySingersModel; }

signals:
    void regularSingerDeleted(const int regularID);
    void regularSingerRenamed(const int regularID, const QString newName);

private slots:
    void on_btnClose_clicked();
    void on_tableViewRegulars_clicked(const QModelIndex &index);
    void on_tableViewRegulars_customContextMenuRequested(const QPoint &pos);
    void renameHistorySinger();
    void on_lineEditSearch_textChanged(const QString &arg1);
    void on_tableViewRegulars_doubleClicked(const QModelIndex &index);

public slots:
    void regularsChanged();
    void toggleVisibility();

    // QWidget interface
protected:
    void closeEvent(QCloseEvent *event) override;
};

#endif // REGULARSINGERSDIALOG_H
